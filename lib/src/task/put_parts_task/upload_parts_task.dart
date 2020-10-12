part of 'put_parts_task.dart';

/// uploadPart 的返回体
class UploadPart {
  String etag;
  String md5;

  UploadPart({this.etag, this.md5});

  factory UploadPart.fromJson(Map json) {
    return UploadPart(etag: json['etag'] as String, md5: json['md5'] as String);
  }

  Map toJson() {
    return {'etag': etag, 'md5': md5};
  }
}

/// 批处理上传 parts 的任务，为 [CompletePartsTask] 提供 [Part]
class UploadPartsTask extends RequestTask<List<Part>> with CacheMixin {
  String token;
  String host;
  String uploadId;
  File file;
  String bucket;
  String key;
  int partSize;
  int maxPartsRequestNumber;

  @override
  String _cacheKey;

  /// 文件 bytes 长度
  int _fileByteLength;

  /// 每个上传分片的字节长度
  ///
  /// 文件会按照此长度切片
  int _partByteLength;

  /// 上传成功后把 part 信息存起来
  final List<Part> _parts = [];

  /// 读文件起始点偏移量
  int _byteStartOffset = 0;

  /// 当前上传到哪一块 chunk
  int _partNumber = 0;

  /// 剩余多少被允许的请求数
  int _idleRequestNumber;

  UploadPartsTask({
    this.token,
    this.host,
    this.partSize,
    this.uploadId,
    this.file,
    this.bucket,
    this.key,
    this.maxPartsRequestNumber,
  });

  @override
  void preStart() {
    _fileByteLength = file.lengthSync();
    _partByteLength = partSize * 1024 * 1024;
    _idleRequestNumber = maxPartsRequestNumber;
    _cacheKey =
        'qiniu_dart_sdk_upload_parts_task_${file.path}_key_${key}_size_$_fileByteLength';
    super.preStart();
  }

  @override
  void postReceive(data) {
    setCache(data.map((_data) => _data.toJson()).toString());
    super.postReceive(data);
  }

  @override
  Future<List<Part>> createTask() async {
    final uploadParts = getCache();
    if (uploadParts != null) {
      _parts.addAll(json.decode(uploadParts) as List<Part>);
    }
    final com = Completer<List<Part>>();
    _uploadParts(() => com.complete(_parts), com.completeError);

    return com.future;
  }

  void _uploadParts(void Function() done, void Function(dynamic) error) {
    while (_idleRequestNumber > 0 && _byteStartOffset < _fileByteLength) {
      _partNumber++;

      final uploadedPart = _parts.isNotEmpty
          ? _parts.firstWhere((element) => element.partNumber == _partNumber)
          : null;

      /// 跳过已经上传完成的分片
      if (uploadedPart != null) {
        continue;
      }

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
        token: token,
        host: host,
        bucket: bucket,
        key: key,
        byteLength: _byteLength,
        byteStream: byteStream,
        uploadId: uploadId,
        partNumber: _partNumber,
      )..addProgressListener((sent, total) {
          _sent += sent;
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

  /// 已发送的文件字节长度
  int _sent = 0;

  void notifyProgress() {
    notifyProgressListeners(_sent, _fileByteLength);
  }
}

/// 上传一个 part 的任务
class UploadPartTask extends RequestTask<UploadPart> {
  String token;
  String host;
  String bucket;
  String key;
  String uploadId;

  /// 字节流的长度
  ///
  /// 如果 data 是 Stream 的话，Dio 需要判断 content-length 才会调用 onSendProgress
  /// https://github.com/flutterchina/dio/blob/21136168ab39a7536835c7a59ce0465bb05feed4/dio/lib/src/dio.dart#L1000
  int byteLength;
  int partNumber;
  Stream<List<int>> byteStream;

  UploadPartTask({
    this.token,
    this.host,
    this.bucket,
    this.key,
    this.uploadId,
    this.byteLength,
    this.byteStream,
    this.partNumber,
  });

  @override
  Future<UploadPart> createTask() async {
    final response = await client.put<Map>(
        '$host/buckets/$bucket/objects/${base64Url.encode(utf8.encode(key))}/uploads/$uploadId/$partNumber',
        data: byteStream,
        options: Options(headers: {
          Headers.contentLengthHeader: byteLength,
          'Authorization': 'UpToken $token'
        }));

    return UploadPart.fromJson(response.data);
  }
}
