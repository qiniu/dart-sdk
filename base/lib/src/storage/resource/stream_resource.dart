part of 'resource.dart';

// BETA
class StreamResource extends Resource<Stream<List<int>>> {
  StreamResource(Stream<List<int>> resource, int length, {int? partSize})
      : super(resource, length, partSize: partSize);

  @override
  Stream<List<int>> createStream() async* {
    final nextChunk = <int>[];
    await for (var chunk in resource) {
      nextChunk.addAll(chunk);
      final chunkStream = _readChunk(nextChunk);
      await for (var _chunk in chunkStream) {
        if (_chunk.length == chunkSize) {
          yield _chunk;
        } else {
          yield _chunk;
          nextChunk
            ..clear()
            ..addAll(_chunk);
        }
      }
    }
  }

  Stream<List<int>> _readChunk(List<int> chunk) async* {
    var count = chunk.length / chunkSize;
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
