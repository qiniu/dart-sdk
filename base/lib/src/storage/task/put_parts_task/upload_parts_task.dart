part of 'put_parts_task.dart';

/// uploadPart 的返回体
class UploadPart {
  final String md5;
  final String etag;

  UploadPart({
    required this.md5,
    required this.etag,
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

/// 批处理上传 parts 的任务，为 [CompletePartsTask] 提供 [Part]
class UploadPartsTask extends RequestTask<List<Part>> with CacheMixin {
  final File file;
  final String token;
  final String bucket;
  final String uploadId;
  final String host;

  final int partSize;
  final int maxPartsRequestNumber;

  final String? key;

  @override
  late final String _cacheKey;

  /// 文件 bytes 长度
  late final int _fileByteLength;

  /// 每个上传分片的字节长度
  ///
  /// 文件会按照此长度切片
  late final int _partByteLength;

  /// 文件总共被拆分的分片数
  late final int _totalPartCount;

  /// 上传成功后把 part 信息存起来
  final Map<int, Part> _uploadPartMap = {};

  /// 已发送的数据记录，key 是 partNumber, value 是 已发送的长度
  final Map<int, int> _sentMap = {};

  /// 剩余多少被允许的请求数
  late int _idleRequestNumber;

  UploadPartsTask({
    required this.file,
    required this.token,
    required this.bucket,
    required this.uploadId,
    required this.host,
    required this.partSize,
    required this.maxPartsRequestNumber,
    this.key,
  });

  static String getCacheKey(
    String path,
    int length,
    int partSize,
    String? key,
  ) {
    final keyMap = {
      'key': key,
      'path': path,
      'file_size': length,
      'part_size': partSize,
    };

    final keyString =
        keyMap.entries.map((e) => '${e.key}/${e.value}').join('/');
    return 'qiniu_dart_sdk_upload_parts_task@[$keyString]';
  }

  @override
  void preStart() {
    _fileByteLength = file.lengthSync();
    _partByteLength = partSize * 1024 * 1024;
    _idleRequestNumber = maxPartsRequestNumber;
    _totalPartCount = (_fileByteLength / _partByteLength).ceil();
    _cacheKey = getCacheKey(file.path, _fileByteLength, partSize, key);
    _uploadPartMap.addAll(getUploadedPartFromCache());
    super.preStart();
  }

  @override
  void postReceive(data) {
    storeUploadedPartToCache();
    super.postReceive(data);
  }

  @override
  void postError(Object error) {
    /// 取消，网络问题等可能导致上传中断，缓存已上传的分片信息
    storeUploadedPartToCache();
    super.postError(error);
  }

  void storeUploadedPartToCache() {
    if (_uploadPartMap.isEmpty) {
      return;
    }

    setCache(json.encode(_uploadPartMap));
  }

  // 从缓存恢复已经上传的 part
  Map<int, Part> getUploadedPartFromCache() {
    /// 获取缓存
    final cachedData = getCache();
    final cachedPartMap = <int, Part>{};

    /// 尝试从缓存恢复
    if (cachedData != null) {
      try {
        cachedPartMap.addAll(json.decode(cachedData) as Map<int, Part>);
      } catch (error) {
        //
      }
    }

    return cachedPartMap;
  }

  @override
  Future<List<Part>> createTask() async {
    await _uploadParts();
    return _uploadPartMap.values.toList();
  }

  Future<void> _uploadParts({int partNumber = 0}) async {
    var _partNumber = partNumber;

    while (_idleRequestNumber > 0 && _partNumber <= _totalPartCount) {
      _partNumber++;
      _idleRequestNumber--;

      /// 根据 part 读取文件
      final byteStream = _readFileByPartNumber(_partNumber);

      /// 上传分片(part)的字节大小
      final _byteLength = (_partNumber == _totalPartCount)
          ? _fileByteLength % _partByteLength
          : _partByteLength;

      late final Part _part;

      final partNumber = _partNumber;
      final _uploadPart = _uploadPartMap[partNumber];

      if (_uploadPart != null) {
        _part = _uploadPart;
        _sentMap[partNumber] = _byteLength;
        notifyProgress();
      } else {
        final task = UploadPartTask(
          token: token,
          bucket: bucket,
          uploadId: uploadId,
          host: host,
          byteStream: byteStream,
          partNumber: _partNumber,
          byteLength: _byteLength,
          key: key,
        )..addProgressListener((sent, total) {
            _sentMap[partNumber] = sent;
            notifyProgress();
          });

        manager.addTask(task);

        try {
          final data = await task.future;
          _part = Part(partNumber: partNumber, etag: data.etag);
        } catch (error) {
          rethrow;
        }
      }

      _idleRequestNumber++;
      _uploadPartMap[partNumber] = _part;

      /// 检查任务是否已经完成
      if (_uploadPartMap.length >= _totalPartCount) {
        return;
      } else {
        return await _uploadParts(partNumber: _partNumber);
      }
    }
  }

  // 根据 index 获取
  Stream<List<int>> _readFileByPartNumber(int partNumber) {
    assert(0 <= partNumber && partNumber <= _totalPartCount);

    final startOffset = partNumber * _partByteLength;
    final endOffset = startOffset + _partByteLength;

    return file.openRead(startOffset, endOffset);
  }

  void notifyProgress() {
    final _sent = _sentMap.values.reduce((value, element) => value + element);
    notifyProgressListeners(_sent, _fileByteLength);
  }
}

/// 上传一个 part 的任务
class UploadPartTask extends RequestTask<UploadPart> {
  final String token;
  final String bucket;
  final String uploadId;
  final String host;

  /// 字节流的长度
  ///
  /// 如果 data 是 Stream 的话，Dio 需要判断 content-length 才会调用 onSendProgress
  /// https://github.com/flutterchina/dio/blob/21136168ab39a7536835c7a59ce0465bb05feed4/dio/lib/src/dio.dart#L1000
  final int byteLength;
  final int partNumber;
  final Stream<List<int>> byteStream;

  final String? key;

  UploadPartTask({
    required this.token,
    required this.bucket,
    required this.uploadId,
    required this.host,
    required this.byteLength,
    required this.partNumber,
    required this.byteStream,
    this.key,
  });

  @override
  Future<UploadPart> createTask() async {
    final headers = <String, dynamic>{
      'Authorization': 'UpToken $token',
      Headers.contentLengthHeader: byteLength,
    };

    final paramMap = <String, String>{
      'buckets': bucket,
      'uploads': uploadId,
    };

    if (key != null) {
      paramMap.addAll({'objects': base64Url.encode(utf8.encode(key!))});
    }

    final response = await client.put<Map<String, dynamic>>(
      '$host/${paramMap.entries.map((e) => "${e.key}/${e.value}").join("/")}/$partNumber',
      data: byteStream,
      options: Options(headers: headers),
    );

    return UploadPart.fromJson(response.data);
  }
}
