import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../storage.dart';
import '../utils.dart';

/// 创建块的返回体
class InitParts {
  String uploadId;
  String expireAt;

  InitParts({this.uploadId, this.expireAt});

  factory InitParts.fromJson(Map json) {
    return InitParts(uploadId: json['uploadId'], expireAt: json['expireAt']);
  }
}

/// 上传块的返回体
class UploadParts {
  String etag;
  String md5;

  UploadParts({this.etag, this.md5});

  factory UploadParts.fromJson(Map json) {
    return UploadParts(etag: json['etag'], md5: json['md5']);
  }
}

class CompleteParts {
  /// 资源内容的 SHA1 值
  String hash;

  /// 上传到七牛云存储后资源名称
  String key;

  CompleteParts({this.hash, this.key});

  factory CompleteParts.fromJson(Map json) {
    return CompleteParts(hash: json['hash'], key: json['key']);
  }
}

class UploadPartsApi {
  String host;
  String token;
  UploadPartsApi({this.host, this.token});

  /// 初始化文件， 返回后续分片上传的 uploadId
  ///
  /// 文档地址：
  ///
  /// https://github.com/qbox/product/blob/master/kodo/resumable-up-v2/init_parts.md
  Future<InitParts> initParts({String bucket, String key}) async {
    try {
      final response = await http.post(
          '$host/buckets/$bucket/objects/${urlSafeBase64Decode(key)}/uploads',
          options: Options(headers: {
            'Content-Length': 0,
            'Authorization': 'UpToken $token'
          }));

      return InitParts.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  /// 上传文件块， 并返回上传块的 Etag
  Future<UploadParts> uploadParts(
      {String bucket,
      String key,
      String uploadId,
      int partNumber,
      Uint8List bytes}) async {
    try {
      final response = await http.put(
          '$host/buckets/$bucket/objects/$key/uploads/$uploadId/$partNumber',
          data: bytes,
          options: Options(headers: {
            'Content-Length': bytes.lengthInBytes,
            'Authorization': 'UpToken $token'
          }));

      return UploadParts.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  /// 将上传好的所有数据块按指定顺序合并成一个资源文件。
  Future<CompleteParts> completeParts(
      {String bucket,
      String key,
      String uploadId,
      String etag,
      int partNumber,
      Uint8List bytes}) async {
    try {
      final response = await http.post(
          '$host/buckets/$bucket/objects/$key/uploads/$uploadId',
          data: {
            'parts': [
              {'etag': etag, 'partNumber': partNumber}
            ]
          },
          options: Options(headers: {
            'Content-Length': bytes.lengthInBytes,
            'Authorization': 'UpToken $token'
          }));

      return CompleteParts.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }
}
