import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../../../../auth/auth.dart';
import '../../../task/request_task.dart';
import '../put_response.dart';

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
    RequestTaskController controller,
  })  : assert(file != null),
        assert(token != null),
        assert(partSize != null),
        assert(maxPartsRequestNumber != null),
        assert(() {
          if (partSize < 1 || partSize > 1024) {
            throw RangeError.range(partSize, 1, 1024, 'partSize',
                'partSize must be greater than 1 and less than 1024');
          }
          return true;
        }()),
        super(controller: controller);

  RequestTaskController _currentWorkingTaskController;

  /// 已发送字节长度
  int _sent = 0;

  /// 文件字节长度
  int _total = 0;

  @override
  void preStart() {
    final putPolicy = Auth.parseUpToken(token).putPolicy;
    bucket = putPolicy.getBucket();
    controller?.cancelToken?.whenCancel?.then((_) {
      _currentWorkingTaskController?.cancel();
    });
    super.preStart();
  }

  @override
  void postReceive(PutResponse data) {
    _currentWorkingTaskController = null;
    super.postReceive(data);
  }

  @override
  Future<PutResponse> createTask() async {
    /// 如果已经取消了，直接报错
    // ignore: null_aware_in_condition
    if (controller?.cancelToken?.isCancelled) {
      throw DioError(type: DioErrorType.CANCEL);
    }

    final host = await config.hostProvider.getUpHost(token: token);

    final initPartsTask = _createInitParts(host);
    final initParts = await initPartsTask.future;

    final uploadParts = _createUploadParts(host, initParts.uploadId);

    PutResponse putResponse;
    try {
      final parts = await uploadParts.future;
      putResponse =
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
        if (error.response.statusCode == 612) {
          return createTask();
        }
      }

      rethrow;
    }

    /// 上传完成，清除缓存
    initPartsTask.clearCache();
    uploadParts.clearCache();

    return putResponse;
  }

  /// 初始化上传信息，分片上传的第一步
  InitPartsTask _createInitParts(String host) {
    final _controller = RequestTaskController();

    final task = InitPartsTask(
      file: file,
      token: token,
      bucket: bucket,
      host: host,
      key: key,
      controller: _controller,
    );

    manager.addRequestTask(task);
    _currentWorkingTaskController = _controller;
    return task;
  }

  UploadPartsTask _createUploadParts(String host, String uploadId) {
    final _controller = RequestTaskController();

    final task = UploadPartsTask(
      file: file,
      token: token,
      bucket: bucket,
      host: host,
      partSize: partSize,
      uploadId: uploadId,
      maxPartsRequestNumber: maxPartsRequestNumber,
      key: key,
      controller: _controller,
    );

    _controller.addProgressListener((sent, total) {
      /// complete parts 没完成之前应该是 99%，所以 + 1
      notifyProgress(sent, total + 1);
    });

    manager.addRequestTask(task);
    _currentWorkingTaskController = _controller;
    return task;
  }

  /// 创建文件，分片上传的最后一步
  CompletePartsTask _createCompleteParts(
    String host,
    String uploadId,
    List<Part> parts,
  ) {
    final _controller = RequestTaskController();
    final task = CompletePartsTask(
      token: token,
      bucket: bucket,
      uploadId: uploadId,
      parts: parts,
      host: host,
      key: key,
      controller: _controller,
    );

    _controller.addProgressListener((sent, total) {
      /// UploadPartsTask 那边给 total 做了 +1 的操作，这里完成后补上 1 字节确保 100%
      notifyProgress(_sent + 1, _total);
    });

    manager.addRequestTask(task);
    _currentWorkingTaskController = _controller;
    return task;
  }

  void notifyProgress(int sent, int total) {
    _sent = sent;
    _total = total;
    controller?.notifyProgressListeners(_sent, _total);
  }
}
