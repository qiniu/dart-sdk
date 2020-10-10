import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:qiniu_sdk_base/src/auth/auth.dart';
import 'package:qiniu_sdk_base/src/task/abstract_request_task.dart';

part 'init_parts_task.dart';
part 'upload_parts_task.dart';
part 'complete_parts_task.dart';
part 'part.dart';
part 'cache_mixin.dart';

/// 分片上传任务
class PutPartsTask extends AbstractRequestTask<CompleteParts> {
  File file;
  String key;
  String token;
  String bucket;
  int partSize;
  int maxPartsRequestNumber;
  Protocol putprotocol;

  PutPartsTask({
    this.key,
    this.file,
    this.token,
    this.partSize,
    this.maxPartsRequestNumber,
    this.putprotocol,
  });

  AbstractRequestTask _currentWorkingTask;

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
    final host = await config.hostProvider.getHostByToken(token, putprotocol);

    final initPartsTask = _createInitParts(host);
    final initParts = await initPartsTask.future;

    final uploadParts = _createUploadParts(host, initParts.uploadId);
    final parts = await uploadParts.future;

    CompleteParts completeParts;
    try {
      completeParts =
          await _createCompleteParts(host, initParts.uploadId, parts).future;
    } catch (e) {
      /// 如果服务端文件被删除了，清除本地缓存
      if (e is DioError && e.response.statusCode == 612) {
        initPartsTask.clearCache();
        uploadParts.clearCache();
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
    )..addProgressListener(notifyProgress);

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
        notifyProgress();
      });

    return _currentWorkingTask =
        manager.addRequestTask(task) as CompletePartsTask;
  }

  int _sent = 0;
  int _total = 0;

  void notifyProgress([int sent, int total]) {
    _sent = sent ?? _sent;
    _total = total ?? _total;
    notifyProgressListeners(_sent, _total);
  }
}
