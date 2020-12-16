part of 'put_parts_task.dart';

// 上传一个 part 的任务
class UploadPartTask extends RequestTask<UploadPart> {
  final String token;
  final String uploadId;
  final RandomAccessFile raf;
  final int partSize;

  // 如果 data 是 Stream 的话，Dio 需要判断 content-length 才会调用 onSendProgress
  // https://github.com/flutterchina/dio/blob/21136168ab39a7536835c7a59ce0465bb05feed4/dio/lib/src/dio.dart#L1000
  final int byteLength;

  final int partNumber;

  final String key;

  TokenInfo _tokenInfo;

  UploadPartTask({
    @required this.token,
    @required this.raf,
    @required this.uploadId,
    @required this.byteLength,
    @required this.partNumber,
    @required this.partSize,
    this.key,
    RequestTaskController controller,
  }) : super(controller: controller);

  @override
  void preStart() {
    _tokenInfo = Auth.parseUpToken(token);
    super.preStart();
  }

  @override
  void postReceive(UploadPart data) {
    // 上传完成后汇报进度
    controller?.notifyProgressListeners(byteLength, byteLength);
    super.postReceive(data);
  }

  // 覆盖默认的 onSendProgress，不要在发送的时候汇报进度
  @override
  void onSendProgress(sent, total) {}

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
    final startOffset = (partNumber - 1) * partSize * 1024 * 1024;
    raf.setPositionSync(startOffset);
    return raf.readSync(byteLength);
  }
}

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
