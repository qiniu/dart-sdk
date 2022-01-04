part of 'resource.dart';

class FileResource extends Resource<File> {
  late RandomAccessFile raf;
  FileResource(File resource, int fileLength, {int? partSize})
      : super(resource, fileLength, partSize: partSize);

  @override
  String get id => 'path_${resource.path}_size_${resource.lengthSync()}';

  @override
  Future<void> open() async {
    raf = resource.openSync();
    await super.open();
  }

  @override
  Future<void> close() async {
    raf.closeSync();
    await super.close();
  }

  @override
  Stream<List<int>> createStream() async* {
    var start = 0;
    while (true) {
      raf.setPositionSync(start);
      yield await raf.read(chunkSize);
      start += chunkSize;
      if (start >= length) break;
    }
  }
}
