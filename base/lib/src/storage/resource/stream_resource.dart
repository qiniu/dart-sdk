part of 'resource.dart';

class StreamResource extends Resource<Stream<List<int>>> {
  StreamController<List<int>> _controller = StreamController<List<int>>();
  late StreamSubscription _subscription;
  late final String _id;

  StreamResource({
    required Stream<List<int>> stream,
    required int length,
    required String id,
    int? partSize,
  }) : super(rawResource: stream, length: length, partSize: partSize) {
    _id = id;
  }

  @override
  String get id => _id;

  @override
  Future<void> open() async {
    await super.open();
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
      _controller = StreamController<List<int>>();
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
