part of 'resource.dart';

class BytesResource extends Resource {
  List<int> bytes;
  BytesResource({
    required this.bytes,
    required int length,
    int? partSize,
  }) : super(length: length, partSize: partSize);

  @override
  String get id => md5.convert(bytes).toString();

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
}
