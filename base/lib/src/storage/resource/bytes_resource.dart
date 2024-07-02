part of 'resource.dart';

class BytesResource extends Resource {
  final List<int> bytes;
  @override
  final String id;
  BytesResource({
    required this.bytes,
    required super.length,
    super.name,
    super.partSize,
  }) : id = md5.convert(bytes).toString();

  late StreamController<List<int>> _controller;

  @override
  Future<void> close() async {
    if (status == ResourceStatus.Open) {
      await _controller.close();
    }
    return await super.close();
  }

  @override
  Stream<List<int>> createStream() {
    var start = 0;

    _controller = StreamController<List<int>>.broadcast(
      onListen: () {
        final end = start + chunkSize > length ? length : start + chunkSize;
        _controller.add(bytes.sublist(start, end));
        start = end;
        if (start >= length) _controller.close();
      },
    );

    return _controller.stream;
  }

  @override
  String toString() {
    return 'bytes@$id';
  }
}
