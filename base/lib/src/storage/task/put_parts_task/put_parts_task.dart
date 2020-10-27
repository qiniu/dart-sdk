import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../../../auth/auth.dart';
import '../put_response.dart';
import '../request_task.dart';

part 'cache_mixin.dart';
part 'complete_parts_task.dart';
part 'init_parts_task.dart';
part 'part.dart';
part 'upload_parts_task.dart';

/// 分片上传任务
class PutByPartTask extends RequestTask<PutResponse> {
  final File file;
  final String token;

  final int partSize;
  final int maxPartsRequestNumber;

  final String key;

  /// 在 preStart 中延迟初始化
  String bucket;

  PutByPartTask({
    @required this.file,
    @required this.token,
    @required this.partSize,
    @required this.maxPartsRequestNumber,
    this.key,
  }) : assert(
          1 < partSize || partSize < 1024,
          'partSize must be greater than 1 and less than 1024',
        );

  RequestTask _currentWorkingTask;

  /// 重试次数
  int retryLimit = 5;

  /// 已发送字节长度
  int _sent = 0;

  /// 文件字节长度
  int _total = 0;

  @override
  void preStart() {
    final putPolicy = Auth.parseToken(token).putPolicy;
    if (putPolicy == null) {
      throw ArgumentError('invalid token');
    }

    bucket = putPolicy.getBucket();

    super.preStart();
  }

  @override
  void postReceive(PutResponse data) {
    _currentWorkingTask = null;
    super.postReceive(data);
  }

  @override
  void cancel() {
    /// FIXME: 可能 task 已经完成，这里的调用就会报错
    _currentWorkingTask?.cancel();
    super.cancel();
  }

  @override
  Future<PutResponse> createTask() async {
    final host = await config.hostProvider.getUpHost(token: token);

    final initPartsTask = _createInitParts(host);
    final initParts = await initPartsTask.future;

    final uploadParts = _createUploadParts(host, initParts.uploadId);

    PutResponse completeParts;
    try {
      final parts = await uploadParts.future;
      completeParts =
          await _createCompleteParts(host, initParts.uploadId, parts).future;
    } catch (error) {
      if (error is DioError && error.response != null) {
        /// 满足以下两种情况清理缓存：
        /// 1、如果服务端文件被删除了，清除本地缓存
        /// 2、如果 uploadId 等参数不对原因会导致 400
        if (error.response.statusCode == 612 ||
            error.response.statusCode == 400) {
          initPartsTask.clearCache();
          uploadParts.clearCache();
        }

        /// 如果服务端文件被删除了，重新上传
        if (error.response.statusCode == 612 && retryLimit > 0) {
          retryLimit--;
          return createTask();
        }
      }

      rethrow;
    }

    /// 上传完成，清除缓存
    initPartsTask.clearCache();
    uploadParts.clearCache();

    return completeParts;
  }

  /// 初始化上传信息，分片上传的第一步
  InitPartsTask _createInitParts(String host) {
    final task = InitPartsTask(
      file: file,
      token: token,
      bucket: bucket,
      host: host,
      key: key,
    );

    return _currentWorkingTask = manager.addTask(task) as InitPartsTask;
  }

  UploadPartsTask _createUploadParts(String host, String uploadId) {
    final task = UploadPartsTask(
      file: file,
      token: token,
      bucket: bucket,
      host: host,
      partSize: partSize,
      uploadId: uploadId,
      maxPartsRequestNumber: maxPartsRequestNumber,
      key: key,
    )..addProgressListener((sent, total) {
        /// complete parts 没完成之前应该是 99%，所以 + 1
        notifyProgress(sent, total + 1);
      });

    return _currentWorkingTask = manager.addTask(task) as UploadPartsTask;
  }

  /// 创建文件，分片上传的最后一步
  CompletePartsTask _createCompleteParts(
    String host,
    String uploadId,
    List<Part> parts,
  ) {
    final task = CompletePartsTask(
      token: token,
      bucket: bucket,
      uploadId: uploadId,
      parts: parts,
      host: host,
      key: key,
    )..addProgressListener((sent, total) {
        /// UploadPartsTask 那边给 total 做了 +1 的操作，这里完成后补上 1 字节确保 100%
        notifyProgress(_sent + 1, _total);
      });

    return _currentWorkingTask = manager.addTask(task) as CompletePartsTask;
  }

  void notifyProgress(int sent, int total) {
    _sent = sent;
    _total = total;
    notifyProgressListeners(_sent, _total);
  }
}
