part of 'put_parts_task.dart';

// 上传一个 part 的任务
class UploadPartTask extends RequestTask<UploadPart> {
  final String token;
  final String uploadId;
  final List<int> bytes;
  final int partSize;

  // 如果 data 是 Stream 的话，Dio 需要判断 content-length 才会调用 onSendProgress
  // https://github.com/cfug/dio/blob/v5.0.0/dio/lib/src/dio_mixin.dart#L633
  final int byteLength;

  final int partNumber;

  final String? key;

  late final UpTokenInfo _tokenInfo;

  UploadPartTask({
    required this.token,
    required this.bytes,
    required this.uploadId,
    required this.byteLength,
    required this.partNumber,
    required this.partSize,
    this.key,
    PutController? controller,
  }) : super(controller: controller);

  @override
  void preStart() {
    _tokenInfo = Auth.parseUpToken(token);
    super.preStart();
  }

  @override
  void postReceive(data) {
    controller?.notifyProgressListeners(1);
    super.postReceive(data);
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

    final encodedKey = key != null ? base64Url.encode(utf8.encode(key!)) : '~';
    final paramUrl = 'buckets/$bucket/objects/$encodedKey';

    final response = await client.put<Map<String, dynamic>>(
      '$host/$paramUrl/uploads/$uploadId/$partNumber',
      data: Stream.fromIterable([bytes.cast<int>()]),
      // 在 data 是 stream 的场景下， interceptor 传入 cancelToken 这里不传会有 bug
      cancelToken: controller?.cancelToken,
      options: Options(
        headers: headers,
        contentType: 'application/octet-stream',
      ),
    );

    return UploadPart.fromJson(response.data!);
  }

  // 分片上传是手动从 File 拿一段数据大概 4m(直穿是直接从 File 里面读取)
  // 如果文件是 21m，假设切片是 4 * 5
  // 外部进度的话会导致一下长到 90% 多，然后变成 100%
  // 解决方法是覆盖父类的 onSendProgress，让 onSendProgress 不处理 Progress 的进度
  // 改为发送成功后通知(见 postReceive)
  @override
  void onSendProgress(double percent) {
    controller?.notifySendProgressListeners(percent);
  }
}

// uploadPart 的返回体
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
