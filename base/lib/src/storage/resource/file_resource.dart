part of 'resource.dart';

class FileResource extends Resource<File> {
  late RandomAccessFile raf;
  List<RandomAccessFile> waitingForCloseRafs = [];
  FileResource({
    required File file,
    required int length,
    int? partSize,
  }) : super(rawResource: file, length: length, partSize: partSize);

  @override
  String get id => 'path_${rawResource.path}_size_${rawResource.lengthSync()}';

  late StreamController<List<int>> _controller;

  @override
  Future<void> open() async {
    raf = await rawResource.open();
    return await super.open();
  }

  @override
  Future<void> close() async {
    if (status == ResourceStatus.Open) {
      waitingForCloseRafs.add(raf);
      await _controller.close();
    }
    return await super.close();
  }

  @override
  Stream<List<int>> createStream() {
    var start = 0;

    _controller = StreamController<List<int>>.broadcast(
      onListen: () {
        raf.setPositionSync(start);
        _controller.add(raf.readSync(chunkSize));
        // 连不上报错可能导致还在有 read 的任务，这时立即 close 操作会触发冲突
        // 文件读完检测一下当前 raf 是不是已经打算被 close
        // 不改成 raf.openRead 那种方式，是因为这种方式省内存
        if (waitingForCloseRafs.contains(raf)) {
          raf.closeSync();
          waitingForCloseRafs.remove(raf);
        }
        start += chunkSize;
        if (start >= length) _controller.close();
      },
    );

    return _controller.stream;
  }

  @override
  String toString() {
    return rawResource.toString();
  }
}
