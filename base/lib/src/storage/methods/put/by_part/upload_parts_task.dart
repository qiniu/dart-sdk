part of 'put_parts_task.dart';

// uploadPart 的返回体
class UploadPart {
  final String md5;
  final String etag;

  UploadPart({
    @required this.md5,
    @required this.etag,
  });

  factory UploadPart.fromJson(Map json) {
    return UploadPart(
      md5: json['md5'] as String,
      etag: json['etag'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'etag': etag,
      'md5': md5,
    };
  }
}

// 批处理上传 parts 的任务，为 [CompletePartsTask] 提供 [Part]
class UploadPartsTask extends RequestTask<List<Part>> with CacheMixin {
  final File file;
  final String token;
  final String uploadId;
  final VoidCallback onRestart;

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
    @required this.onRestart,
    this.key,
    RequestTaskController controller,
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
    final _controller = RequestTaskController();
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
      onRestart: onRestart,
    );

    _controller.addProgressListener((sent, total) {
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
    controller?.notifyProgressListeners(_sent, _fileByteLength);
  }
}

// 上传一个 part 的任务
class UploadPartTask extends RequestTask<UploadPart> {
  final String token;
  final String uploadId;
  final VoidCallback onRestart;
  final RandomAccessFile raf;
  final int partSize;

  // 如果 data 是 Stream 的话，Dio 需要判断 content-length 才会调用 onSendProgress
  // https://github.com/flutterchina/dio/blob/21136168ab39a7536835c7a59ce0465bb05feed4/dio/lib/src/dio.dart#L1000
  final int byteLength;

  final int partNumber;

  final String key;

  TokenInfo _tokenInfo;
  int _partByteLength;

  UploadPartTask({
    @required this.token,
    @required this.raf,
    @required this.uploadId,
    @required this.byteLength,
    @required this.partNumber,
    @required this.partSize,
    @required this.onRestart,
    this.key,
    RequestTaskController controller,
  }) : super(controller: controller);

  @override
  void preStart() {
    _tokenInfo = Auth.parseUpToken(token);
    _partByteLength = partSize * 1024 * 1024;
    super.preStart();
  }

  @override
  void postRestart() {
    onRestart();
    super.postRestart();
  }

  @override
  Future<UploadPart> createTask() async {
    final headers = <String, dynamic>{
      'Authorization': 'UpToken $token',
      Headers.contentLengthHeader: byteLength,
    };

    final bucket = _tokenInfo.putPolicy.getBucket();

    final host = await config.hostProvider.getUpHost(
      bucket: bucket,
      accessKey: _tokenInfo.accessKey,
    );

    final encodedKey = key != null ? base64Url.encode(utf8.encode(key)) : '~';
    final paramUrl = 'buckets/$bucket/objects/$encodedKey';

    final response = await client.put<Map<String, dynamic>>(
      '$host/$paramUrl/uploads/$uploadId/$partNumber',
      data: Stream.fromIterable([_readFileByPartNumber(partNumber)]),
      // 在 data 是 stream 的场景下， interceptor 传入 cancelToken 这里不传会有 bug
      cancelToken: controller.cancelToken,
      options: Options(headers: headers),
    );

    return UploadPart.fromJson(response.data);
  }

  // 根据 partNumber 获取要上传的文件片段
  List<int> _readFileByPartNumber(int partNumber) {
    final startOffset = (partNumber - 1) * _partByteLength;
    raf.setPositionSync(startOffset);
    return raf.readSync(byteLength);
  }
}
