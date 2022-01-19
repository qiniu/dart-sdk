part of 'resource.dart';

final _uuid = Uuid();

// 没法保证数据源重新 listen 后能拿到 first event，所以 [StreamResource] 只支持续传模式(把数据源转变成 Broadcast stream)
class StreamResource extends Resource<Stream<List<int>>> {
  StreamController<List<int>> _controller = StreamController<List<int>>();
  late StreamSubscription _subscription;
  late final String _id;

  StreamResource({
    required Stream<List<int>> stream,
    required int length,
    String? id,
    int? partSize,
  }) : super(
          rawResource: stream.isBroadcast ? stream : stream.asBroadcastStream(),
          length: length,
          partSize: partSize,
        ) {
    // 如果没有 id 则声称随机的 id
    // 同一个 [rawStream] close 后再 open 会继续接收 event 而不是从头开始
    // 设置一个随机 id，可帮助失败重试功能的时候能跳过已缓存的分片(存在 DefaultCacheProvider 里)
    _id = id ?? _uuid.v4();
  }

  @override
  String get id => _id;

  /// 重新 open 的
  @override
  Future<void> open() async {
    await super.open();
    _controller = StreamController<List<int>>();
    _subscription = rawResource.listen(
      _controller.add,
      onDone: _controller.close,
      onError: _controller.addError,
    );
  }

  @override
  Future<void> close() async {
    if (status == ResourceStatus.Open) {
      await _subscription.cancel();
      await _controller.close();
    }
    await super.close();
  }

  @override
  Stream<List<int>> createStream() async* {
    final nextChunk = <int>[];
    await for (var chunk in _controller.stream) {
      nextChunk.addAll(chunk);
      final chunkStream = _readChunk(nextChunk);
      await for (var _chunk in chunkStream) {
        if (_chunk.length == chunkSize) {
          yield _chunk;
          nextChunk.removeRange(0, chunkSize);
        } else {
          nextChunk
            ..clear()
            ..addAll(_chunk);
          // 如果收到的 chunk 过小，则暂存起来和下次收到的 chunk 合并再 _readChunk 一次
          continue;
        }
      }
    }
    yield nextChunk;
  }

  // 尝试从 chunk 中读取出符合 chunkSize 大小的 chunk, chunkSize 是根据 partSize 算出来的
  Stream<List<int>> _readChunk(List<int> chunk) async* {
    var count = (chunk.length / chunkSize).floor();
    var start = 0;
    while (count-- > 0) {
      var end = (chunk.length >= start + chunkSize)
          ? start + chunkSize
          : chunk.length;
      yield chunk.sublist(start, end);
      start += chunkSize;
    }
  }
}
