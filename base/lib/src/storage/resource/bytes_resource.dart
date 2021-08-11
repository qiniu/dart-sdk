part of 'resource.dart';

class BytesResource extends Resource {
  final Uint8List bytes;
  BytesResource(this.bytes);

  @override
  String get id => md5.convert(bytes).toString();

  @override
  void close() {}

  @override
  void open() {}

  @override
  Uint8List read(int start, int count) {
    return bytes.sublist(start, start + count);
  }

  @override
  Uint8List readAsBytes() {
    return bytes;
  }

  @override
  int length() {
    return bytes.length;
  }
}
