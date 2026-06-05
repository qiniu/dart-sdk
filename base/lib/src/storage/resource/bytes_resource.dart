part of 'resource.dart';

class BytesResource extends Resource {
  final List<int> bytes;

  BytesResource({
    required this.bytes,
    required super.length,
    super.name,
    super.partSize,
  }) : super(id: md5.convert(bytes).toString());

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

    // 使用 broadcast + onListen 推进 [start] 实现"分次拉取"的非标准协议：
    // 每次新 listener 订阅都会从当前 [start] 位置 emit 一个 chunk，
    // emit 完成后立即结束本次订阅（不 close controller，下一次 listen 还能继续）。
    // 这是 [Resource.stream] 对外约定的行为，调用方可以连续 `await for ... break`
    // 接力读完整资源；详见 `resource_test.dart` 的契约测试。
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

  @override
  String toString() {
    return 'bytes@$id';
  }
}
