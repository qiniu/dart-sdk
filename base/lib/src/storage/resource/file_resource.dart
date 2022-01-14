part of 'resource.dart';

class FileResource extends Resource<File> {
  late RandomAccessFile raf;
  FileResource({
    required File file,
    required int length,
    int? partSize,
  }) : super(rawResource: file, length: length, partSize: partSize);

  @override
  String get id => 'path_${rawResource.path}_size_${rawResource.lengthSync()}';

  @override
  Future<void> open() async {
    raf = await rawResource.open();
    await super.open();
  }

  @override
  Future<void> close() async {
    if (status == ResourceStatus.Open) {
      await raf.close();
    }
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
