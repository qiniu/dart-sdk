import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:qiniu_sdk_base/src/auth/auth.dart';
import 'package:qiniu_sdk_base/src/task/request_task.dart';

part 'init_parts_task.dart';
part 'upload_parts_task.dart';
part 'complete_parts_task.dart';
part 'part.dart';
part 'cache_mixin.dart';

/// 分片上传任务
class PutPartsTask extends RequestTask<CompleteParts> {
  File file;
  String key;
  String token;
  String bucket;
  int partSize;
  int maxPartsRequestNumber;

  PutPartsTask({
    this.key,
    this.file,
    this.token,
    this.partSize,
    this.maxPartsRequestNumber,
  });

  RequestTask _currentWorkingTask;

  /// 已发送字节长度
  int _sent = 0;

  /// 文件字节长度
  int _total = 0;

  /// 612 之后重试次数
  int _retryCountWhile612 = 3;

  @override
  void preStart() {
    bucket = Auth.parseToken(token).putPolicy.getBucket();
    super.preStart();
  }

  @override
  void postReceive(CompleteParts data) {
    _currentWorkingTask = null;
    super.postReceive(data);
  }

  @override
  void cancel() {
    _currentWorkingTask?.cancel();
    super.cancel();
  }

  @override
  Future<CompleteParts> createTask() async {
    final host = await config.hostProvider.getUpHost(token: token);

    final initPartsTask = _createInitParts(host);
    final initParts = await initPartsTask.future;

    final uploadParts = _createUploadParts(host, initParts.uploadId);

    CompleteParts completeParts;
    try {
      final parts = await uploadParts.future;
      completeParts =
          await _createCompleteParts(host, initParts.uploadId, parts).future;
    } catch (e) {
      if (e is DioError) {
        /// 满足以下两种情况清理缓存：
        /// 1、如果服务端文件被删除了，清除本地缓存
        /// 2、如果 uploadId 等参数不对原因会导致 400
        if (e.response.statusCode == 612 || e.response.statusCode == 400) {
          initPartsTask.clearCache();
          uploadParts.clearCache();
        }

        /// 如果服务端文件被删除了，重新上传
        if (e.response.statusCode == 612) {
          return await createTask();
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
      token: token,
      host: host,
      bucket: bucket,
      key: key,
      file: file,
    );

    return _currentWorkingTask = manager.addRequestTask(task) as InitPartsTask;
  }

  UploadPartsTask _createUploadParts(String host, String uploadId) {
    final task = UploadPartsTask(
      token: token,
      host: host,
      bucket: bucket,
      key: key,
      file: file,
      partSize: partSize,
      uploadId: uploadId,
      maxPartsRequestNumber: maxPartsRequestNumber,
    )..addProgressListener((sent, total) {
        /// complete parts 没完成之前应该是 99%，所以 + 1
        notifyProgress(sent, total + 1);
      });

    return _currentWorkingTask =
        manager.addRequestTask(task) as UploadPartsTask;
  }

  /// 创建文件，分片上传的最后一步
  CompletePartsTask _createCompleteParts(
    String host,
    String uploadId,
    List<Part> parts,
  ) {
    final task = CompletePartsTask(
      token: token,
      host: host,
      bucket: bucket,
      key: key,
      uploadId: uploadId,
      parts: parts,
    )..addProgressListener((sent, total) {
        /// UploadPartsTask 那边给 total 做了 +1 的操作，这里完成后补上 1 字节确保 100%
        notifyProgress(_sent + 1, _total);
      });

    return _currentWorkingTask =
        manager.addRequestTask(task) as CompletePartsTask;
  }

  void notifyProgress(int sent, int total) {
    _sent = sent;
    _total = total;
    notifyProgressListeners(_sent, _total);
  }
}
