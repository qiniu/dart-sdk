part of 'resource.dart';

class FileResource extends Resource {
  final File file;
  late RandomAccessFile raf;
  FileResource(this.file);

  @override
  String get id => 'path_${file.path}_size_${file.lengthSync()}';

  @override
  void open() {
    raf = file.openSync();
  }

  @override
  void close() {
    raf.closeSync();
  }

  @override
  Uint8List read(int start, int count) {
    raf.setPositionSync(start);
    return raf.readSync(count);
  }

  @override
  Uint8List readAsBytes() {
    return file.readAsBytesSync();
  }

  @override
  int length() {
    return file.lengthSync();
  }
}
