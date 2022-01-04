part of 'resource.dart';

class BytesResource extends Resource<List<int>> {
  BytesResource(List<int> bytes, int byteLength, {int? partSize})
      : super(bytes, byteLength, partSize: partSize);

  @override
  String get id => md5.convert(resource).toString();

  @override
  Stream<List<int>> createStream() async* {
    var start = 0;
    while (true) {
      final end = start + chunkSize > length ? length : start + chunkSize;
      yield resource.sublist(start, end);
      start = end;
      if (start >= length) break;
    }
  }
}
