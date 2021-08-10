part of 'resource.dart';

class FileResource extends Resource {
  final File file;
  late RandomAccessFile raf;
  FileResource(this.file);

  @override
  String get id => 'path_${file.path}_size_${file.lengthSync()}';

  @override
  void open() {
    // 子任务 UploadPartTask 从 file 去 open 的话虽然上传精度会颗粒更细但是会导致可能读不出文件的问题
    // 可能 close 没办法立即关闭 file stream，而延迟 close 了，导致某次 open 的 stream 被立即关闭
    // 所以读不出内容了
    // 改成这里 open 一次，子任务从中读取 bytes
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
