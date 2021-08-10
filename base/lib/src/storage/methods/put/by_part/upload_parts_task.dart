part of 'put_parts_task.dart';

// 批处理上传 parts 的任务，为 [CompletePartsTask] 提供 [Part]
class UploadPartsTask extends RequestTask<List<Part>> with CacheMixin {
  final String token;
  final String uploadId;

  final int partSize;
  final int maxPartsRequestNumber;

  final String? key;

  @override
  late final String _cacheKey;

  /// 设置为 0，避免子任务重试失败后 [UploadPartsTask] 继续重试
  @override
  int get retryLimit => 0;

  // 文件 bytes 长度
  late final int _resourceByteLength;

  // 每个上传分片的字节长度
  //
  // 文件会按照此长度切片
  late final int _partByteLength;

  // 文件总共被拆分的分片数
  late final int _totalPartCount;

  // 上传成功后把 part 信息存起来
  final Map<int, Part> _uploadedPartMap = {};

  // 处理分片上传任务的 UploadPartTask 的控制器
  final List<RequestTaskController> _workingUploadPartTaskControllers = [];

  // 已发送分片数量
  int _sentPartCount = 0;

  // 已发送到服务器的数量
  int _sentPartToServerCount = 0;

  // 剩余多少被允许的请求数
  late int _idleRequestNumber;

  final Resource resource;

  UploadPartsTask({
    required this.token,
    required this.uploadId,
    required this.partSize,
    required this.maxPartsRequestNumber,
    required this.resource,
    this.key,
    PutController? controller,
  }) : super(controller: controller);

  static String getCacheKey(
    String resourceId,
    int partSize,
    String? key,
  ) {
    final keyList = [resourceId, 'key/$key', 'part_size/$partSize'];

    return 'qiniu_dart_sdk_upload_parts_task@[${keyList..join("/")}]';
  }

  @override
  void preStart() {
    super.preStart();
    // 当前 controller 被取消后，所有运行中的子任务都需要被取消
    controller?.cancelToken.whenCancel.then((_) {
      for (final controller in _workingUploadPartTaskControllers) {
        controller.cancel();
      }
    });
    _resourceByteLength = resource.length();
    _partByteLength = partSize * 1024 * 1024;
    _idleRequestNumber = maxPartsRequestNumber;
    _totalPartCount = (_resourceByteLength / _partByteLength).ceil();
    _cacheKey = getCacheKey(resource.id, _resourceByteLength, key);
    resource.open();
  }

  @override
  void postReceive(data) async {
    resource.close();
    super.postReceive(data);
  }

  @override
  void postError(Object error) async {
    resource.close();
    // 取消，网络问题等可能导致上传中断，缓存已上传的分片信息
    await storeUploadedPart();
    super.postError(error);
  }

  Future storeUploadedPart() async {
    if (_uploadedPartMap.isEmpty) {
      return;
    }

    await setCache(jsonEncode(_uploadedPartMap.values.toList()));
  }

  // 从缓存恢复已经上传的 part
  Future recoverUploadedPart() async {
    // 获取缓存
    final cachedData = await getCache();
    // 尝试从缓存恢复
    if (cachedData != null) {
      var cachedList = <Part>[];

      try {
        final _cachedList = json.decode(cachedData) as List<dynamic>;
        cachedList = _cachedList
            .map((dynamic item) => Part.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (error) {
        rethrow;
      }

      for (final part in cachedList) {
        _uploadedPartMap[part.partNumber] = part;
      }
    }
  }

  @override
  Future<List<Part>> createTask() async {
    /// 如果已经取消了，直接报错
    // ignore: null_aware_in_condition
    if (controller != null && controller!.isCancelled) {
      throw StorageError(type: StorageErrorType.CANCEL);
    }

    controller?.notifyStatusListeners(StorageStatus.Request);
    // 尝试恢复缓存，如果有
    await recoverUploadedPart();

    // 上传分片
    await _uploadParts();
    return _uploadedPartMap.values.toList();
  }

  int _uploadingPartIndex = 0;

  // 从指定的分片位置往后上传切片
  Future<void> _uploadParts() async {
    final tasksLength =
        min(_idleRequestNumber, _totalPartCount - _uploadingPartIndex);
    final taskFutures = <Future<Null>>[];

    while (taskFutures.length < tasksLength &&
        _uploadingPartIndex < _totalPartCount) {
      // partNumber 按照后端要求必须从 1 开始
      final partNumber = ++_uploadingPartIndex;

      final _uploadedPart = _uploadedPartMap[partNumber];
      if (_uploadedPart != null) {
        _sentPartCount++;
        _sentPartToServerCount++;
        notifySendProgress();
        notifyProgress();
        continue;
      }

      final future = _createUploadPartTaskFutureByPartNumber(partNumber);
      taskFutures.add(future);
    }

    await Future.wait<Null>(taskFutures);
  }

  Future<Null> _createUploadPartTaskFutureByPartNumber(int partNumber) async {
    // 上传分片(part)的字节大小
    final _byteLength = _getPartSizeByPartNumber(partNumber);

    _idleRequestNumber--;
    final _controller = PutController();
    _workingUploadPartTaskControllers.add(_controller);

    final task = UploadPartTask(
      token: token,
      bytes: _getBytesFromResource(partNumber),
      uploadId: uploadId,
      byteLength: _byteLength,
      partNumber: partNumber,
      partSize: partSize,
      key: key,
      controller: _controller,
    );

    _controller
      // UploadPartTask 一次上传一个 chunk，通知一次进度
      ..addSendProgressListener((percent) {
        _sentPartCount++;
        notifySendProgress();
      })
      // UploadPartTask 上传完成后触发
      ..addProgressListener((percent) {
        _sentPartToServerCount++;
        notifyProgress();
      });

    manager.addTask(task);

    final data = await task.future;

    _idleRequestNumber++;
    _uploadedPartMap[partNumber] =
        Part(partNumber: partNumber, etag: data.etag);
    _workingUploadPartTaskControllers.remove(_controller);

    await storeUploadedPart();

    // 检查任务是否已经完成
    if (_uploadedPartMap.length != _totalPartCount) {
      // 上传下一片
      await _uploadParts();
    }
  }

  // 根据 partNumber 算出当前切片的 byte 大小
  int _getPartSizeByPartNumber(int partNumber) {
    final startOffset = (partNumber - 1) * _partByteLength;

    if (partNumber == _totalPartCount) {
      return _resourceByteLength - startOffset;
    }

    return _partByteLength;
  }

  Uint8List _getBytesFromResource(int partNumber) {
    final start = (partNumber - 1) * _partByteLength;
    final count = _getPartSizeByPartNumber(partNumber);

    return resource.read(start, count);
  }

  void notifySendProgress() {
    controller?.notifySendProgressListeners(_sentPartCount / _totalPartCount);
  }

  void notifyProgress() {
    controller?.notifyProgressListeners(_sentPartToServerCount /
        _totalPartCount *
        RequestTask.onSendProgressTakePercentOfTotal);
  }
}
