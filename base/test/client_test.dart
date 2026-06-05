@Timeout(Duration(seconds: 60))
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/src/client/http_client_adapter.dart';
import 'package:test/test.dart';

void main() {
  group('QiniuHttpClient', () {
    test(
      'write timeout triggers when downstream pauses for too long',
      () async {
        // 写阶段是 pause-driven：必须由下游 pause 我们才会开表。
        // 这里用 _PauseAndStallAdapter 模拟 IOSink/socket 写不动：
        // 拿到 subscription 立刻 pause 且永不 resume。
        final controller = StreamController<Uint8List>();
        final client = QiniuHttpClient(
          writeTimeout: const Duration(milliseconds: 100),
          readTimeout: Duration.zero,
          delegate: _PauseAndStallAdapter(),
        );
        controller.add(Uint8List.fromList([1, 2, 3]));

        try {
          await client.fetch(RequestOptions(), controller.stream, null);
          fail('expected QiniuIdleTimeoutException');
        } on QiniuIdleTimeoutException catch (e) {
          expect(e.phase, QiniuIdleTimeoutException.writePhase);
          expect(e.message, 'write idle timeout');
        }
        await controller.close();
        client.close();
      },
    );

    test(
      'write timeout does NOT trigger when upstream stalls but downstream is ok',
      () async {
        // 反例：上游卡住、没有 pause → 写阶段不该误报。
        // 上游 onDone 之后进入「等待响应头」阶段，由 readTimeout 接管。
        // 这里 readTimeout=Zero 所以也不会触发，最终靠 controller 关闭走到完成路径。
        final controller = StreamController<Uint8List>();
        final client = QiniuHttpClient(
          writeTimeout: const Duration(milliseconds: 100),
          readTimeout: Duration.zero,
          delegate: _SlowReadAdapter(),
        );
        controller.add(Uint8List.fromList([1, 2, 3]));

        // 给 writeTimeout 充分超过的时间，期望「不」触发
        final fetchFuture = client.fetch(
          RequestOptions(),
          controller.stream,
          null,
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
        // 关闭上游让 fetch 自然完成
        await controller.close();
        await fetchFuture; // 不应该抛异常
        client.close();
      },
    );

    test('read timeout triggers when response stream stalls', () async {
      final responseController = StreamController<Uint8List>();
      final client = QiniuHttpClient(
        writeTimeout: Duration.zero,
        readTimeout: const Duration(milliseconds: 100),
        delegate: _StallResponseAdapter(responseController.stream),
      );
      // 先发一块响应数据，然后卡住
      responseController.add(Uint8List.fromList([1, 2, 3]));

      try {
        final response = await client.fetch(RequestOptions(), null, null);
        await for (final _ in response.stream) {
          // 收到第一块数据后不再有数据，超时触发
        }
        fail('expected QiniuIdleTimeoutException');
      } on QiniuIdleTimeoutException catch (e) {
        expect(e.phase, QiniuIdleTimeoutException.readPhase);
        expect(e.message, 'read idle timeout');
      }
      await responseController.close();
      client.close();
    });

    test('no timeout when Duration.zero', () async {
      final client = QiniuHttpClient(
        writeTimeout: Duration.zero,
        readTimeout: Duration.zero,
        delegate: _EchoAdapter(),
      );
      final data = Uint8List.fromList([1, 2, 3]);

      final response =
          await client.fetch(RequestOptions(), Stream.value(data), null);
      final received = <Uint8List>[];
      await for (final chunk in response.stream) {
        received.add(chunk);
      }
      expect(received.length, 1);
      expect(received.first, data);
      client.close();
    });

    test('no timeout when data flows within timeout', () async {
      final responseController = StreamController<Uint8List>();
      final client = QiniuHttpClient(
        writeTimeout: Duration.zero,
        readTimeout: const Duration(seconds: 5),
        delegate: _StallResponseAdapter(responseController.stream),
      );

      final response = await client.fetch(RequestOptions(), null, null);

      // 在 fetch 返回后异步发送数据
      Future<void> sendData() async {
        await Future.delayed(const Duration(milliseconds: 50));
        responseController.add(Uint8List.fromList([1]));
        await Future.delayed(const Duration(milliseconds: 50));
        responseController.add(Uint8List.fromList([2]));
        await Future.delayed(const Duration(milliseconds: 50));
        responseController.add(Uint8List.fromList([3]));
        await responseController.close();
      }

      final received = <Uint8List>[];
      await Future.wait([
        sendData(),
        (() async {
          await for (final chunk in response.stream) {
            received.add(chunk);
          }
        })(),
      ]);
      expect(received.length, 3);
      client.close();
    });

    test(
      'write timeout does not leak unhandled exception to zone',
      () async {
        // 回归测试：闲时超时触发 abort 后 fetchFuture 也会以错误 reject，
        // Future.any 不会消化未取走的失败。必须挂 catchError 兜底，
        // 否则会进入 zone uncaughtError handler 产生 "Unhandled Exception"。
        final unhandledErrors = <Object>[];
        await runZonedGuarded(() async {
          final controller = StreamController<Uint8List>();
          final client = QiniuHttpClient(
            writeTimeout: const Duration(milliseconds: 50),
            readTimeout: Duration.zero,
            delegate: _PauseAndStallAdapter(),
          );
          controller.add(Uint8List.fromList([1, 2, 3]));
          try {
            await client.fetch(RequestOptions(), controller.stream, null);
          } on QiniuIdleTimeoutException {
            // expected
          }
          // 等迟到的 abort 错误流过
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await controller.close();
          client.close();
        }, (error, stack) {
          unhandledErrors.add(error);
        });
        expect(unhandledErrors, isEmpty);
      },
    );

    test('connectTimeout is set on options when not specified', () async {
      const connectTimeout = Duration(seconds: 15);
      final client = QiniuHttpClient(
        connectTimeout: connectTimeout,
        delegate: _ConnectTimeoutAssertAdapter(connectTimeout),
      );
      await client.fetch(RequestOptions(), null, null);
      client.close();
    });

    test(
      'non-idle errors from delegate are surfaced (not swallowed to empty resp)',
      () async {
        // 回归测试问题 2：delegate 自身失败时（比如 dio 的 sendTimeout、
        // 网络错误等），idle timer 不会触发，错误必须能透传给上层，
        // 不能被 catchError 吃成空 ResponseBody
        final client = QiniuHttpClient(
          writeTimeout: const Duration(seconds: 10),
          readTimeout: const Duration(seconds: 10),
          delegate: _AlwaysFailAdapter(),
        );
        try {
          await client.fetch(RequestOptions(), null, null);
          fail('expected StateError from delegate');
        } on StateError catch (e) {
          expect(e.message, 'delegate failure');
        }
        client.close();
      },
    );
  });
}

/// 拿到 requestStream 后立刻 pause 且永不 resume，
/// 模拟 IOSink/socket 写满了再也没空——用来触发 pause-driven 的 write timeout。
class _PauseAndStallAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    StreamSubscription<Uint8List>? sub;
    final completer = Completer<ResponseBody>();
    cancelFuture?.whenComplete(() {
      sub?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('canceled'),
          StackTrace.current,
        );
      }
    });
    if (requestStream != null) {
      sub = requestStream.listen(
        (_) {},
        onError: (Object e, StackTrace s) {
          if (!completer.isCompleted) completer.completeError(e, s);
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(ResponseBody(Stream.empty(), 200, headers: {}));
          }
        },
      );
      // 立即背压：模拟下游写不动
      sub.pause();
    } else {
      completer.complete(ResponseBody(Stream.empty(), 200, headers: {}));
    }
    return completer.future;
  }

  @override
  void close({bool force = false}) {}
}

/// 消费请求流到底，正常路径，用于测试「上游慢、下游 OK」不该误报写超时
class _SlowReadAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) {
      await for (final _ in requestStream) {
        // 读完所有数据
      }
    }
    return ResponseBody(Stream.empty(), 200, headers: {});
  }

  @override
  void close({bool force = false}) {}
}

/// 响应流可外部控制，用于测试 read timeout
class _StallResponseAdapter implements HttpClientAdapter {
  final Stream<Uint8List> _responseStream;

  _StallResponseAdapter(this._responseStream);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody(_responseStream, 200, headers: {});
  }

  @override
  void close({bool force = false}) {}
}

/// 将请求体原样返回，用于测试正常流程
class _EchoAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        body.addAll(chunk);
      }
    }
    return ResponseBody(
      Stream.value(Uint8List.fromList(body)),
      200,
      headers: {},
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 验证 connectTimeout 被正确设置
class _ConnectTimeoutAssertAdapter implements HttpClientAdapter {
  final Duration expectedConnectTimeout;

  _ConnectTimeoutAssertAdapter(this.expectedConnectTimeout);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.connectTimeout, expectedConnectTimeout);
    return ResponseBody(Stream.empty(), 200, headers: {});
  }

  @override
  void close({bool force = false}) {}
}

/// 始终以错误结束，模拟 delegate 自身失败（非 idle timeout）
class _AlwaysFailAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw StateError('delegate failure');
  }

  @override
  void close({bool force = false}) {}
}
