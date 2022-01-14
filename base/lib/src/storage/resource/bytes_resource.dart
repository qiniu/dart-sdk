part of 'resource.dart';

class BytesResource extends Resource<List<int>> {
  BytesResource({
    required List<int> bytes,
    required int length,
    int? partSize,
  }) : super(rawResource: bytes, length: length, partSize: partSize);

  @override
  String get id => md5.convert(rawResource).toString();

  @override
  Stream<List<int>> createStream() async* {
    var start = 0;
    while (true) {
      final end = start + chunkSize > length ? length : start + chunkSize;
      yield rawResource.sublist(start, end);
      start = end;
      if (start >= length) break;
    }
  }
}
