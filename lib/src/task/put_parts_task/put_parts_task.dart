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

/// 分片上传任务
class PutPartsTask extends AbstractRequestTask<CompleteParts> {
  File file;
  String key;
  String token;
  String bucket;
  int partSize;
  dynamic region;
  int maxPartsRequestNumber;
  Protocol protocol;

  PutPartsTask({
    this.key,
    this.file,
    this.token,
    this.partSize,
    this.region,
    this.maxPartsRequestNumber,
    this.protocol,
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
    final host = region != null
        ? config.regionProvider.getHostByRegion(region)
        : await config.regionProvider.getHostByToken(token);

    final initParts = await _createInitParts(host).future;

    final parts = await _createUploadParts(host, initParts.uploadId).future;

    final completeParts =
        await _createCompleteParts(host, initParts.uploadId, parts).future;

    return completeParts;
  }

  /// 初始化上传信息，分片上传的第一步
  InitPartsTask _createInitParts(String host) {
    final task = InitPartsTask(
      token: token,
      host: host,
      bucket: bucket,
      key: key,
    );

    return _currentWorkingTask = manager.addRequestTask(task);
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
    );

    task.addProgressListener((sent, total) {
      notifyProgress(sent, total);
    });

    return _currentWorkingTask = manager.addRequestTask(task);
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
    );

    task.addProgressListener((sent, total) {
      notifyProgress();
    });

    return _currentWorkingTask = manager.addRequestTask(task);
  }

  int _sent = 0;
  int _total = 0;

  void notifyProgress([int sent, int total]) {
    _sent = sent ?? _sent;
    _total = total ?? _total;
    notifyProgressListeners(_sent, _total);
  }
}
