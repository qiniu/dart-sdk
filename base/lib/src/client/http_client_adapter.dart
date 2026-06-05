import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import 'delegate_factory.dart';

/// 七牛自定义 HTTP 客户端
///
/// 包装 dio 默认 [HttpClientAdapter]（Native 端为 `IOHttpClientAdapter`、
/// Web 端为 `BrowserHttpClientAdapter`），在其之上补充：
/// - 连接超时 [connectTimeout]
/// - 请求体闲时超时 [writeTimeout]（pause-driven，监测 socket 写不动）
/// - 响应体闲时超时 [readTimeout]（data-driven，监测 socket 不再来数据）
///
/// "请求体发完到响应头到达"之间这段不再做应用层检测，
/// 交给 OS TCP 重传超时（macOS/iOS ~18s，errno=60）兜底。
///
/// 仍允许通过构造器的 `delegate` 参数注入自定义底层适配器，
/// 此时 [sendBufferSize] 不再生效（由调用方自行控制底层连接行为）。
class QiniuHttpClient implements HttpClientAdapter {
  /// TCP 连接建立超时
  ///
  /// 与服务端建立 TCP 连接（三次握手）的最大等待时间，默认 10 秒。
  /// 超时后触发 [DioExceptionType.connectionTimeout] 错误。
  ///
  /// 若不设置，各操作系统默认等待时间差异较大：
  /// - Linux/Android: 约 60 秒
  /// - macOS/iOS: 约 75 秒
  /// - Windows: 约 21 秒
  final Duration connectTimeout;

  /// 写入闲时超时，类似 socket 的 SO_SNDTIMEO
  ///
  /// 请求体流两次数据流动之间的最大等待时间，默认 30 秒。
  /// 超时后触发 [TimeoutException]。
  ///
  /// 仅在 Native 平台生效。Web 平台无 socket 背压机制，
  /// 此超时不会触发，需依赖浏览器自身的网络超时。
  final Duration writeTimeout;

  /// 读取闲时超时，类似 socket 的 SO_RCVTIMEO
  ///
  /// 响应体两次数据流动之间的最大等待时间：响应传输过程中网络中断、
  /// 服务端卡住等情况下兜底取消请求。默认 30 秒。
  ///
  /// 注意：此超时不覆盖"请求体发完到响应头到达"之间的等待，
  /// 该阶段无应用层信号可用，依赖 OS TCP 重传超时兜底。
  final Duration readTimeout;

  /// TCP 发送缓冲区大小（字节），默认 128KB
  ///
  /// 设置后会通过 [Socket.setRawOption] 限制内核 send buffer 上限，
  /// 让大块数据无法一次写完，触发 IOSink 背压链路 pause 我们的 source，
  /// 从而让 [writeTimeout] 的"闲时"语义恢复成"传输停顿"，
  /// 而不是退化为"事件流动后的整体计时器"。
  ///
  /// 传入 null 时沿用 OS 自动调优（macOS/iOS 通常自动放大到几 MB），
  /// 此时如果上层一次写入的分片大于内核缓冲（典型 4MB 分片场景），
  /// [writeTimeout] 会因 onDone 提前到达而失效。
  ///
  /// 仅在 Native 平台生效，Web 平台会忽略此参数。
  ///
  /// 推荐范围：128 * 1024（128KB）~ 256 * 1024（256KB）
  /// - 过小（< 64KB）：TCP 拥塞窗口拉不起来，影响吞吐
  /// - 过大（接近分片大小）：失去触发 pause-driven idle 检测的作用
  /// - 默认 128KB 与分片上传的次级切片大小（`_kUploadPartChunkBytes`，
  ///   见 `upload_part_task.dart`，64KB）配套：每两片刚好填满一次内核
  ///   send buffer，IOSink 每 1 次 pause/resume，使 [writeTimeout] 的
  ///   pause-driven 探测时间粒度稳定在「写不动 128KB」的层级。
  ///   修改任一方时请同步评估另一方。
  final int? sendBufferSize;

  final HttpClientAdapter _delegate;

  QiniuHttpClient({
    this.connectTimeout = const Duration(seconds: 10),
    this.writeTimeout = const Duration(seconds: 30),
    this.readTimeout = const Duration(seconds: 30),
    this.sendBufferSize = 128 * 1024,
    HttpClientAdapter? delegate,
  }) : _delegate = delegate ?? createDefaultDelegate(sendBufferSize);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    options.connectTimeout ??= connectTimeout;

    // 本地取消信号：任一 idle timeout 触发时 complete，dio 收到后会 abort 底层请求。
    // 这是关键：底层 IOSink/_HttpOutgoing 的内部 controller 在背压期间会 buffer
    // 所有事件（包括 error），直接调用 onError 无法穿透。必须通过 abort 撕掉 socket
    // 来让 addStream future 真正 reject。
    final localCancel = Completer<void>();
    final mergedCancel = _mergeCancelFuture(cancelFuture, localCancel.future);

    // 用来把 idle 超时的真实错误抛给外层 await（绕过被 buffer 在 controller 里的 onError）。
    // 与 fetch 的 Future race，超时方先 complete 即可让上层立刻拿到 QiniuIdleTimeoutException。
    final timeoutRace = Completer<ResponseBody>();

    void fireIdleTimeout(QiniuIdleTimeoutException err, StackTrace st) {
      // 触发底层 abort，使 dio 的 addStream / response 链路自然终止
      if (!localCancel.isCompleted) localCancel.complete();
      // 给外层 await 一个明确的 QiniuIdleTimeoutException
      if (!timeoutRace.isCompleted) timeoutRace.completeError(err, st);
    }

    // 仅覆盖请求体推送阶段（writeTimeout，pause-driven）；
    // "请求体发完到响应头到达"之间的网络异常不再由我们检测，
    // 交由 OS TCP 重传超时（macOS/iOS ~18s，errno=60）兜底，
    // 一旦响应体开始有数据到达再切换到 readTimeout（data-driven）。
    // writeTimeout <= Duration.zero 时直接透传源流，避免多余的 pause/resume
    // 包装改变 stream 语义（单订阅/广播等）。
    final wrappedRequest = requestStream != null && writeTimeout > Duration.zero
        ? _WriteIdleTimeoutStream(
            requestStream,
            writeTimeout,
            onIdleTimeout: fireIdleTimeout,
          )
        : requestStream;

    final fetchFuture = _delegate.fetch(options, wrappedRequest, mergedCancel);

    // 自定义优先级 race（替代 Future.any）：
    // - 正常成功：fetchFuture 完成，complete success
    // - fetchFuture 自身失败（dio sendTimeout / 网络错误 / badResponse 等）
    //   且 idle timeout 没触发：透传 fetchFuture 的错误
    // - idle timeout 触发：timeoutRace 同步 completeError，其 then 回调早于
    //   fetchFuture 的 cancel reject 进入 microtask 队列，所以 result 必然
    //   先被 timeoutRace 以 QiniuIdleTimeoutException 完成；fetchFuture 之后
    //   迟到的 DioException(cancel) 被 `!result.isCompleted` 守卫挡掉，
    //   既避免覆盖真实错误，也避免 unhandled error 流入 zone
    final result = Completer<ResponseBody>();
    fetchFuture.then(
      (resp) {
        if (!result.isCompleted) result.complete(resp);
      },
      onError: (Object err, StackTrace st) {
        if (!result.isCompleted) result.completeError(err, st);
      },
    );
    timeoutRace.future.then(
      (_) {
        // timeoutRace 只会 completeError，正常路径不会走到这里
      },
      onError: (Object err, StackTrace st) {
        if (!result.isCompleted) result.completeError(err, st);
      },
    );
    final response = await result.future;

    final responseStream = readTimeout > Duration.zero
        ? _ReadIdleTimeoutStream(
            response.stream,
            readTimeout,
            onIdleTimeout: fireIdleTimeout,
          )
        : response.stream;
    var closed = false;
    final wrappedResponse = ResponseBody(
      responseStream,
      response.statusCode,
      statusMessage: response.statusMessage,
      headers: response.headers,
      isRedirect: response.isRedirect,
      redirects: response.redirects,
      // 透传 onClose：dio 在错误状态 / 取消 / receive timeout 等路径会调
      // responseBody.close() 释放底层 socket。response.close() 是 @internal，
      // 用 ignore 抑制；语义上就是「释放上层传入 delegate 提供的底层资源」。
      // ignore: invalid_use_of_internal_member
      onClose: () {
        if (closed) return;
        closed = true;
        // ignore: invalid_use_of_internal_member
        response.close();
      },
    )..extra.addAll(response.extra);
    return wrappedResponse;
  }

  @override
  void close({bool force = false}) {
    _delegate.close(force: force);
  }

  /// 合并两个取消 future，任一完成即视为取消
  Future<void> _mergeCancelFuture(
    Future<void>? external,
    Future<void> internal,
  ) {
    if (external == null) return internal;
    final c = Completer<void>();
    void complete() {
      if (!c.isCompleted) c.complete();
    }

    external.then((_) => complete(), onError: (_) => complete());
    internal.then((_) => complete(), onError: (_) => complete());
    return c.future;
  }
}

/// 七牛 HTTP 客户端的闲时超时错误。
///
/// [phase] 标记是请求体写入超时（[writePhase]）还是响应体读取超时（[readPhase]），
/// 上层 `StorageError.fromDioError` 据此映射到
/// `StorageErrorType.SEND_TIMEOUT` / `StorageErrorType.RECEIVE_TIMEOUT`。
///
/// 实现 [TimeoutException] 接口以兼容上层基于 `is TimeoutException` 的判断。
@internal
class QiniuIdleTimeoutException implements TimeoutException {
  /// 请求体写入阶段标识
  static const String writePhase = 'write';

  /// 响应体读取阶段标识
  static const String readPhase = 'read';

  @override
  final String? message;
  @override
  final Duration? duration;

  /// 阶段标识，取值为 [writePhase] 或 [readPhase]
  final String phase;

  QiniuIdleTimeoutException(this.phase, this.duration)
      : message = '$phase idle timeout';

  @override
  String toString() => 'QiniuIdleTimeoutException($phase, $duration)';
}

/// 闲时超时回调签名
typedef _IdleTimeoutCallback = void Function(
  QiniuIdleTimeoutException err,
  StackTrace st,
);

/// 用与 Stream API 相同的方式调用用户注册的 onError handler，
/// 兼容 `void Function(Object)` 和 `void Function(Object, StackTrace)` 两种签名。
/// 未知签名时回退到 zone 兜底，避免在用户代码里抛 NoSuchMethodError。
void _invokeUserErrorHandler(
  Function handler,
  Object error,
  StackTrace stack,
) {
  if (handler is void Function(Object, StackTrace)) {
    handler(error, stack);
  } else if (handler is void Function(Object)) {
    handler(error);
  } else {
    Zone.current.handleUncaughtError(error, stack);
  }
}

// ---------------------------------------------------------------------------
// 闲时超时检测：两种语义
// ---------------------------------------------------------------------------
//
// 都用来在「源流」和「消费者」之间插入一段计时逻辑，区别在于以什么信号
// 判定「网络停滞」：
//
// 1. [_WriteIdleTimeoutStream]（请求体）—— pause-driven
//    位置：上游（文件/encoder）→ 我们 → IOSink（socket）
//    pause 来自 IOSink/socket，表示「网络/socket 写不动」。这就是要测的「停滞」。
//    - pause: 开表
//    - resume: 停表（socket 又能吃了）
//    - onData/onDone/onError: 不驱动计时器
//
// 2. [_ReadIdleTimeoutStream]（响应体）—— data-driven
//    位置：socket（HttpClientResponse）→ 我们 → 消费者（dio 收集 body）
//    pause 来自消费者，表示「业务侧来不及处理」，跟网络无关。
//    - 源吐出数据: 重置计时器（网络在送数据，没停滞）
//    - 消费者 pause: 停表（是我们主动让网络停的，不该当作网络停滞）
//    - 消费者 resume: 重启计时器
//
// 两者共享 [_IdleTimeoutSubscriptionBase]：统一处理 listen 绑定、handler
// 可替换、_fire（错误传递 + 触发底层 abort）等通用部分；具体语义差异通过
// 三个钩子注入：_onBound / _onSourceData / _onConsumerPause / _onConsumerResume。
//
// 单订阅语义：每个 Stream 实例只能 listen 一次。

abstract class _IdleTimeoutSubscriptionBase
    implements StreamSubscription<Uint8List> {
  final Duration _idleTimeout;

  /// 闲时超时时通知外层（用于触发底层 abort）
  final _IdleTimeoutCallback? _onIdleTimeout;

  /// listen 现场的栈，timer 触发时作为错误堆栈，便于定位调用方。
  /// 在 [_bind] 时抓取（订阅创建点），而非构造时（创建点）。
  StackTrace _listenStack = StackTrace.empty;

  /// 超时阶段标识，子类设置，用于区分写/读超时。
  /// 取值为 [QiniuIdleTimeoutException.writePhase] 或 [QiniuIdleTimeoutException.readPhase]
  final String _phase;

  void Function(Uint8List)? _onData;
  Function? _onError;
  void Function()? _onDone;

  StreamSubscription<Uint8List>? _source;
  Timer? _idleTimer;

  bool _finished = false;
  bool _canceled = false;

  /// 暂停深度：支持连续 pause() / resume() 的嵌套配对。
  /// 仅在 0→1 时触发 _onConsumerPause，1→0 时触发 _onConsumerResume，
  /// 中间层级的 pause/resume 透传给底层 _source，不影响包装层状态。
  int _pauseDepth = 0;

  _IdleTimeoutSubscriptionBase(
    this._idleTimeout,
    this._onIdleTimeout,
    this._phase,
  );

  /// 子类钩子：每次源吐出数据时回调（早于消费者 onData）
  void _onSourceData();

  /// 子类钩子：listen 绑定完成后回调
  void _onBound();

  /// 子类钩子：消费者调用 pause() 时
  void _onConsumerPause();

  /// 子类钩子：消费者调用 resume() 时
  void _onConsumerResume();

  void _bind(
    Stream<Uint8List> source,
    void Function(Uint8List)? onData,
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  ) {
    // 在订阅创建点抓栈，便于 timer 触发时定位调用方
    _listenStack = StackTrace.current;
    _onData = onData;
    _onError = onError;
    _onDone = onDone;

    _source = source.listen(
      (data) {
        _onSourceData();
        if (_finished) return;
        // 经由可变字段读取最新 handler，支持订阅中途替换
        _onData?.call(data);
      },
      onError: (Object e, StackTrace st) {
        if (_finished) return;
        _finished = true;
        _cancelTimer();
        _onError?.call(e, st);
      },
      onDone: () {
        if (_finished) return;
        _finished = true;
        _cancelTimer();
        _onDone?.call();
      },
      cancelOnError: cancelOnError,
    );
    _onBound();
  }

  /// 启动（或重启）计时器，等价于 cancel + arm。
  /// 不区分「首次开启」和「重置」；在 [_finished] / [_idleTimeout]<=0 时无副作用。
  void _startTimer() {
    _idleTimer?.cancel();
    if (_finished) return;
    if (_idleTimeout <= Duration.zero) return;
    _idleTimer = Timer(_idleTimeout, _fire);
  }

  void _cancelTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void _fire() {
    if (_finished) return;
    _finished = true;

    // 立即取消源订阅，避免 timeout 后还有数据回调
    _source?.cancel();

    final err = QiniuIdleTimeoutException(_phase, _idleTimeout);

    // 关键：通过外层回调触发底层 abort。
    // 直接调用消费者 onError 在背压场景下会被 dart:io 的 _HttpOutgoing 内部
    // controller buffer 掉（参考 sdk/lib/_http/http_impl.dart _HttpOutgoing.addStream），
    // 必须通过 abort 撕断 socket 让 addStream future reject。
    _onIdleTimeout?.call(err, _listenStack);

    // 同时调用消费者注册的 onError：
    // - 响应体场景下消费者通常是 await for / toList 等，直接收到错误即可立刻终止；
    // - 请求体场景这一步会被 controller buffer 吞掉，但有上面的 _onIdleTimeout 兜底。
    final handler = _onError;
    if (handler != null) {
      _invokeUserErrorHandler(handler, err, _listenStack);
      return;
    }
    // 没有注册 onError：在响应体直接被丢弃的极少数路径，
    // 且也没有 _onIdleTimeout 兜底时，把错误送到 zone 避免静默失败
    if (_onIdleTimeout == null) {
      Zone.current.handleUncaughtError(err, _listenStack);
    }
  }

  @override
  void onData(void Function(Uint8List)? handleData) {
    _onData = handleData;
  }

  @override
  void onError(Function? handleError) {
    _onError = handleError;
  }

  @override
  void onDone(void Function()? handleDone) {
    _onDone = handleDone;
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    _enterPauseOneLevel();
    // 当调用方传入 resumeSignal 时，底层订阅会在 future 完成后自动恢复一次，
    // 但包装层不会同步 _pauseDepth / timer 状态；需在 whenComplete 中
    // 仅更新包装层状态，不调用会透传 _source.resume() 的 resume()，
    // 否则嵌套场景下底层会被双 resume（自身自动 + 包装层透传），导致
    // 背压提前放开。
    // depth 不会变负：手动 resume() 与 whenComplete 共用 _tryResumeOneLevel
    // 的 depth==0 守卫，多余调用安全早退。
    if (resumeSignal != null) {
      resumeSignal.whenComplete(() {
        if (!_finished && _source != null) {
          _tryResumeOneLevel();
        }
      });
    }
    _source?.pause(resumeSignal);
  }

  @override
  void resume() {
    _tryResumeOneLevel();
    // 始终透传给底层：dart SDK 自身的引用计数会忽略多余的 resume()，不调用则
    // 会破坏嵌套场景下底层计数的对称性。
    _source?.resume();
  }

  /// 尝试将包装层从 paused 状态退出一层。
  /// 仅在 0→1→...→1→0 转换的最后一层（1→0）触发 [_onConsumerResume]。
  /// 多余的 resume()（_pauseDepth 已为 0）不会触发任何钩子。
  void _tryResumeOneLevel() {
    if (_pauseDepth == 0) {
      return;
    }
    _pauseDepth--;
    if (_pauseDepth == 0) {
      _onConsumerResume();
    }
  }

  /// 将包装层进入 paused 状态一层。
  /// 仅在 ...→0→1 转换的首次进入（0→1）触发 [_onConsumerPause]。
  /// 嵌套的 pause() 不会重复触发钩子。
  void _enterPauseOneLevel() {
    _pauseDepth++;
    if (_pauseDepth == 1) {
      _onConsumerPause();
    }
  }

  @override
  bool get isPaused => _source?.isPaused ?? false;

  @override
  Future<void> cancel() async {
    if (_canceled) return;
    _canceled = true;
    _finished = true;
    _cancelTimer();
    await _source?.cancel();
  }

  @override
  Future<E> asFuture<E>([E? futureValue]) =>
      _source?.asFuture<E>(futureValue) ?? Future<E>.value(futureValue as E);
}

/// 写阶段闲时超时：pause-driven。
///
/// 把 [Stream] 喂给 dio 的 `request.addStream` 之前包一层，专测「socket 写不动」。
/// 详见上方综述。
class _WriteIdleTimeoutStream extends Stream<Uint8List> {
  final Stream<Uint8List> _source;
  final Duration _idleTimeout;
  final _IdleTimeoutCallback? _onIdleTimeout;
  bool _listened = false;

  _WriteIdleTimeoutStream(
    this._source,
    this._idleTimeout, {
    _IdleTimeoutCallback? onIdleTimeout,
  }) : _onIdleTimeout = onIdleTimeout;

  @override
  bool get isBroadcast => false;

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    if (_listened) {
      throw StateError(
        '_WriteIdleTimeoutStream has already been listened to.',
      );
    }
    _listened = true;
    final sub = _WriteIdleSubscription(_idleTimeout, _onIdleTimeout);
    sub._bind(_source, onData, onError, onDone, cancelOnError);
    return sub;
  }
}

class _WriteIdleSubscription extends _IdleTimeoutSubscriptionBase {
  _WriteIdleSubscription(
    Duration idleTimeout,
    _IdleTimeoutCallback? onIdleTimeout,
  ) : super(idleTimeout, onIdleTimeout, QiniuIdleTimeoutException.writePhase);

  // 写阶段：onData/onBound 都不启动 timer。
  // 启动时未被 IOSink pause，说明 socket 还能吃，无须开表。
  @override
  void _onSourceData() {}

  @override
  void _onBound() {}

  // 下游 IOSink/socket 写不动 → 开表
  @override
  void _onConsumerPause() {
    _startTimer();
  }

  // socket 又能吃 → 停表
  @override
  void _onConsumerResume() {
    _cancelTimer();
  }
}

/// 读阶段闲时超时：data-driven。
///
/// 把 dio 返回的 response.stream 包一层，专测「socket 不再来数据」。
/// 详见上方综述。
class _ReadIdleTimeoutStream extends Stream<Uint8List> {
  final Stream<Uint8List> _source;
  final Duration _idleTimeout;
  final _IdleTimeoutCallback? _onIdleTimeout;
  bool _listened = false;

  _ReadIdleTimeoutStream(
    this._source,
    this._idleTimeout, {
    _IdleTimeoutCallback? onIdleTimeout,
  }) : _onIdleTimeout = onIdleTimeout;

  @override
  bool get isBroadcast => false;

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    if (_listened) {
      throw StateError(
        '_ReadIdleTimeoutStream has already been listened to.',
      );
    }
    _listened = true;
    final sub = _ReadIdleSubscription(_idleTimeout, _onIdleTimeout);
    sub._bind(_source, onData, onError, onDone, cancelOnError);
    return sub;
  }
}

class _ReadIdleSubscription extends _IdleTimeoutSubscriptionBase {
  _ReadIdleSubscription(
    Duration idleTimeout,
    _IdleTimeoutCallback? onIdleTimeout,
  ) : super(idleTimeout, onIdleTimeout, QiniuIdleTimeoutException.readPhase);

  // 读阶段：数据流过即视为网络活跃，重置计时器
  @override
  void _onSourceData() {
    _startTimer();
  }

  // 绑定完成立即开表，等待第一片数据
  @override
  void _onBound() {
    _startTimer();
  }

  // 消费者主动 pause（业务慢），不该把这段时间算到网络头上
  @override
  void _onConsumerPause() {
    _cancelTimer();
  }

  // 消费者 resume，恢复对网络的闲时检测
  @override
  void _onConsumerResume() {
    _startTimer();
  }
}
