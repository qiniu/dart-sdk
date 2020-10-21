part of 'put_parts_task.dart';

/// uploadPart 的返回体
class UploadPart {
  final String? md5;
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

  /// 上传成功后把 part 信息存起来
  late final List<Part> _parts = [];

  /// 读文件起始点偏移量
  late int _byteStartOffset;

  /// 当前上传到哪一块 chunk
  late int _partNumber;

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

  static String getCacheKey(String path, int length, String? key) {
    return 'qiniu_dart_sdk_upload_parts_task_${path}_key_${key}_size_$length';
  }

  @override
  void preStart() {
    _partByteLength = partSize * 1024 * 1024;
    _idleRequestNumber = maxPartsRequestNumber;
    super.preStart();
  }

  @override
  void postReceive(data) {
    setCache(json.encode(data));
    super.postReceive(data);
  }

  @override
  void postError(Object error) {
    /// 取消，网络问题等可能导致上传中断，缓存已上传的分片信息
    setCache(json.encode(_parts));
    super.postError(error);
  }

  @override
  Future<List<Part>> createTask() async {
    _fileByteLength = await file.length();
    _cacheKey = getCacheKey(file.path, _fileByteLength, key);

    /// 获取缓存
    final uploadPartsCache = getCache();

    /// 尝试从缓存恢复
    if (uploadPartsCache != null) {
      /// FIXME: 尽量不去 as List<Part>
      _parts.addAll(json.decode(uploadPartsCache) as List<Part>);
    }

    final com = Completer<List<Part>>();
    _uploadParts(() => com.complete(_parts), com.completeError);

    return com.future;
  }

  void _uploadParts(void Function() done, void Function(Object) error) {
    while (_idleRequestNumber > 0 && _byteStartOffset < _fileByteLength) {
      _partNumber++;

      final cachedPart = _parts.isNotEmpty
          ? _parts.firstWhere((element) => element.partNumber == _partNumber)
          : null;

      _idleRequestNumber--;

      /// 读文件终点偏移量
      final byteEndOffset = _byteStartOffset + _partByteLength;
      final byteStream = file.openRead(_byteStartOffset, byteEndOffset);

      /// 上传分片(part)的字节大小
      final _byteLength = byteEndOffset > _fileByteLength
          ? _fileByteLength - _byteStartOffset
          : _partByteLength;

      _byteStartOffset += _byteLength;

      final partNumber = _partNumber;

      final task = UploadPartTask(
        cachedPart: cachedPart,
        token: token,
        host: host,
        bucket: bucket,
        key: key,
        byteLength: _byteLength,
        byteStream: byteStream,
        uploadId: uploadId,
        partNumber: _partNumber,
      )..addProgressListener((sent, total) {
          _sentMap[partNumber] = sent;
          notifyProgress();
        });

      task.future.then((data) {
        _idleRequestNumber++;
        _parts.add(Part(partNumber: partNumber, etag: data.etag));
        if (_parts.length == (_fileByteLength / _partByteLength).ceil()) {
          done();
        } else {
          _uploadParts(done, error);
        }
      }).catchError(error);

      manager.addRequestTask(task);
    }
  }

  /// 已发送的数据记录，key 是 partNumber, value 是 已发送的长度
  final Map<int, int> _sentMap = {};

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

  final Part? cachedPart;
  final String? key;

  UploadPartTask({
    required this.token,
    required this.bucket,
    required this.uploadId,
    required this.host,
    required this.byteLength,
    required this.partNumber,
    required this.byteStream,
    this.cachedPart,
    this.key,
  });

  @override
  Future<UploadPart> createTask() async {
    if (cachedPart != null) {
      return UploadPart(etag: cachedPart!.etag, md5: null);
    }

    final headers = <String, dynamic>{
      'Authorization': 'UpToken $token',
      Headers.contentLengthHeader: byteLength,
    };

    final paramMap = <String, String>{'buckets': bucket, 'uploads': uploadId};

    if (key != null) {
      paramMap.addAll({'objects': base64Url.encode(utf8.encode(key!))});
    }

    final response = await client.put<Map<String, dynamic>>(
      '$host/${paramMap.entries.join('/')}/$partNumber',
      data: byteStream,
      options: Options(headers: headers),
    );

    return UploadPart.fromJson(response.data);
  }
}
