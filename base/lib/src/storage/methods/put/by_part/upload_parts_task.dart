part of 'put_parts_task.dart';

// 批处理上传 parts 的任务，为 [CompletePartsTask] 提供 [Part]
class UploadPartsTask extends RequestTask<List<Part>> with CacheMixin {
  final File file;
  final String token;
  final String uploadId;

  final int partSize;
  final int maxPartsRequestNumber;

  final String key;

  @override
  String _cacheKey;

  // 文件 bytes 长度
  int _fileByteLength;

  // 每个上传分片的字节长度
  //
  // 文件会按照此长度切片
  int _partByteLength;

  // 文件总共被拆分的分片数
  int _totalPartCount;

  // 上传成功后把 part 信息存起来
  final Map<int, Part> _uploadedPartMap = {};

  // 处理分片上传任务的 UploadPartTask 的控制器
  final List<RequestTaskController> _workingUploadPartTaskControllers = [];

  // 已发送的数据记录，key 是 partNumber, value 是 已发送的长度
  final Map<int, int> _sentMap = {};

  // 剩余多少被允许的请求数
  int _idleRequestNumber;

  RandomAccessFile _raf;

  UploadPartsTask({
    @required this.file,
    @required this.token,
    @required this.uploadId,
    @required this.partSize,
    @required this.maxPartsRequestNumber,
    this.key,
    PutController controller,
  }) : super(controller: controller);

  static String getCacheKey(
    String path,
    int length,
    int partSize,
    String key,
  ) {
    final keyList = [
      'key/$key',
      'path/$path',
      'file_size/$length',
      'part_size/$partSize',
    ];

    return 'qiniu_dart_sdk_upload_parts_task@[${keyList..join("/")}]';
  }

  @override
  void preStart() {
    // 当前 controller 被取消后，所有运行中的子任务都需要被取消
    controller?.cancelToken?.whenCancel?.then((_) {
      for (final controller in _workingUploadPartTaskControllers) {
        controller.cancel();
      }
    });
    _fileByteLength = file.lengthSync();
    _partByteLength = partSize * 1024 * 1024;
    _idleRequestNumber = maxPartsRequestNumber;
    _totalPartCount = (_fileByteLength / _partByteLength).ceil();
    _cacheKey = getCacheKey(file.path, _fileByteLength, partSize, key);
    recoverUploadedPart();
    _raf = file.openSync();
    super.preStart();
  }

  @override
  void postReceive(data) {
    _raf.close();
    storeUploadedPart();
    super.postReceive(data);
  }

  @override
  void postError(Object error) {
    _raf.close();
    // 取消，网络问题等可能导致上传中断，缓存已上传的分片信息
    storeUploadedPart();
    super.postError(error);
  }

  void storeUploadedPart() {
    if (_uploadedPartMap.isEmpty) {
      return;
    }

    setCache(jsonEncode(_uploadedPartMap.values.toList()));
  }

  // 从缓存恢复已经上传的 part
  void recoverUploadedPart() {
    // 获取缓存
    final cachedData = getCache();
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
    if (controller != null && controller.cancelToken.isCancelled) {
      throw StorageError(type: StorageErrorType.CANCEL);
    }

    controller.notifyStatusListeners(RequestTaskStatus.Request);
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
        _sentMap[partNumber] = _getPartSizeByPartNumber(partNumber);
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
      raf: _raf,
      uploadId: uploadId,
      byteLength: _byteLength,
      partNumber: partNumber,
      partSize: partSize,
      key: key,
      controller: _controller,
    );

    _controller.addSendProgressListener((sent, total) {
      _sentMap[partNumber] = sent;
      notifyProgress();
    });

    manager.addRequestTask(task);

    final data = await task.future;

    _idleRequestNumber++;
    _uploadedPartMap[partNumber] =
        Part(partNumber: partNumber, etag: data.etag);
    _workingUploadPartTaskControllers.remove(_controller);

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
      return _fileByteLength - startOffset;
    }

    return _partByteLength;
  }

  void notifyProgress() {
    final _sent = _sentMap.values.reduce((value, element) => value + element);
    onSendProgress(_sent, _fileByteLength);
  }
}
