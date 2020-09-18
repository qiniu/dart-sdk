import 'dart:io';
import 'dart:typed_data';

import 'package:qiniu_sdk_base/src/api.dart';
import 'package:qiniu_sdk_base/src/apis/UploadParts.dart';
import 'package:qiniu_sdk_base/src/utils.dart';

/// 上传块任务
class UploadPartsTask {
  Uint8List block;
  File file;
  String token;
  UploadPartsApi _uploadPartsApi;

  /// 切片大小。单位 MB，默认 4 MB
  int chunkSize;
  UploadPartsTask(
      {this.block, this.chunkSize = 4, this.file, this.token, String host})
      : _uploadPartsApi = UploadPartsApi(host: host, token: token);

  void start() {
    final bucket = getPutPolicy(token).bucket;
    _uploadPartsApi.initParts(bucket: );
  }
}
