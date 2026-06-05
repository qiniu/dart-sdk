part of 'resource.dart';

class FileResource extends Resource {
  /// 通过文件创建一个 [FileResource]，会把文件的路径、大小、修改时间等信息作为 id 的一部分，以区分不同的文件资源
  late RandomAccessFile raf;

  /// 由于 [FileResource] 的特殊性，在文件读取过程中可能会有 close 操作，这时不能直接在 [close] 里关闭 raf，否则可能会和正在进行的 read 操作冲突，所以等待读取完毕后再关闭 raf
  List<RandomAccessFile> waitingForCloseRafs = [];

  /// 文件资源
  final File file;

  FileResource({
    required this.file,
    required super.length,
    super.name,
    super.partSize,
  }) : super(
          id: 'path_${file.path}_size_${file.lengthSync()}_mtime_${file.lastModifiedSync().millisecondsSinceEpoch}',
        );

  late StreamController<List<int>> _controller;

  @override
  Future<void> open() async {
    raf = await file.open();
    return await super.open();
  }

  @override
  Future<void> close() async {
    if (status == ResourceStatus.Open) {
      // 如果在 [Resource.createStream] 里被关了就不处理了
      if (!_controller.isClosed) {
        waitingForCloseRafs.add(raf);
        await _controller.close();
      }
    }
    return await super.close();
  }

  @override
  Stream<List<int>> createStream() {
    var start = 0;

    // 使用 broadcast + onListen 推进 [start] 实现"分次拉取"的非标准协议：
    // 每次新 listener 订阅都会从当前 [start] 位置 emit 一个 chunk，
    // 不 close controller，下一次 listen 继续接力。
    // 这是 [Resource.stream] 对外约定的行为，调用方可以连续 `await for ... break`
    // 接力读完整资源；详见 `resource_test.dart` 的契约测试。
    //
    // 不改成 `raf.openRead` 那种方式，是因为这种方式省内存。
    _controller = StreamController<List<int>>.broadcast(
      onListen: () {
        raf.setPositionSync(start);
        _controller.add(raf.readSync(chunkSize));
        // 读文件过程中被结束了
        // 连不上报错可能导致还在有 read 的任务，这时立即 close 操作会触发冲突
        // 文件读完检测一下当前 raf 是不是已经打算被 close
        if (waitingForCloseRafs.contains(raf)) {
          raf.closeSync();
          waitingForCloseRafs.remove(raf);
          return;
        }
        start += chunkSize;
        // 文件读取完毕
        if (start >= length) {
          // 如果 raf 还没有被关闭，关闭它
          if (!waitingForCloseRafs.contains(raf)) {
            raf.closeSync();
          }
          _controller.close();
        }
      },
    );

    return _controller.stream;
  }

  @override
  String toString() {
    return 'file@${basename(file.path)}';
  }
}
