import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:qiniu_sdk_base/src/storage/resource/resource.dart';

part 'cache_mixin.dart';
part 'complete_parts_task.dart';
part 'init_parts_task.dart';
part 'part.dart';
part 'upload_part_task.dart';
part 'upload_parts_task.dart';

/// 分片上传任务
class PutByPartTask extends RequestTask<PutResponse> {
  final String token;
  final Resource resource;

  final PutOptions options;

  /// 设置为 0，避免子任务重试失败后 [PutByPartTask] 继续重试
  @override
  int get retryLimit => 0;

  PutByPartTask({
    required this.resource,
    required this.token,
    required this.options,
  }) : super(controller: options.controller);

  RequestTaskController? _currentWorkingTaskController;

  @override
  void preStart() {
    super.preStart();

    // 处理相同任务
    final sameTaskExist = manager
        .getTasks()
        .where((element) => element is PutByPartTask && isEquals(element))
        .isNotEmpty;

    if (sameTaskExist) {
      throw StorageError(
        type: StorageErrorType.IN_PROGRESS,
        message: '$resource 已在上传队列中',
      );
    }
    // controller 被取消后取消当前运行的子任务
    controller?.cancelToken.whenCancel.then((_) {
      _currentWorkingTaskController?.cancel();
    });
  }

  @override
  void postReceive(PutResponse data) {
    super.postReceive(data);
    _currentWorkingTaskController = null;
    resource.close();
  }

  @override
  void postError(Object error) {
    super.postError(error);
    resource.close();
  }

  @override
  Future<PutResponse> createTask() async {
    controller?.notifyStatusListeners(StorageStatus.Request);

    await resource.open();

    final initPartsTask = _createInitParts();
    final initParts = await initPartsTask.future;

    // 初始化任务完成后也告诉外部一个进度
    controller?.notifyProgressListeners(0.002);

    final uploadParts = _createUploadParts(initParts.uploadId);

    PutResponse putResponse;
    try {
      final parts = await uploadParts.future;
      putResponse =
          await _createCompleteParts(initParts.uploadId, parts).future;
    } catch (error) {
      // 拿不到 initPartsTask 和 uploadParts 的引用，所以不放到 postError 去
      if (error is StorageError) {
        /// 满足以下两种情况清理缓存：
        /// 1、如果服务端文件被删除了，清除本地缓存
        /// 2、如果 uploadId 等参数不对原因会导致 400
        if (error.code == 400 || error.code == 612) {
          await initPartsTask.clearCache();
          await uploadParts.clearCache();
        }

        /// 如果服务端文件被删除了，重新上传
        if (error.code == 612) {
          // 如果是 StreamResource，无法保证能从头获取到完整的数据，不做处理
          if (resource is StreamResource) {
            rethrow;
          }
          controller?.notifyStatusListeners(StorageStatus.Retry);
          await resource.close();
          // TODO 调整为重试机制，而不是在这里 rerun，以降低复杂度
          // 记录下子任务，可以解决引用问题
          // 子任务关闭重试机制，重试改为从头开始
          return createTask();
        }
      }

      rethrow;
    }

    /// 上传完成，清除缓存
    await initPartsTask.clearCache();
    await uploadParts.clearCache();

    return putResponse;
  }

  bool isEquals(PutByPartTask target) {
    return target.resource.id == resource.id;
  }

  /// 初始化上传信息，分片上传的第一步
  InitPartsTask _createInitParts() {
    final _controller = PutController();

    final task = InitPartsTask(
      resource: resource,
      token: token,
      key: options.key,
      controller: _controller,
    );

    manager.addTask(task);
    _currentWorkingTaskController = _controller;
    return task;
  }

  UploadPartsTask _createUploadParts(String uploadId) {
    final _controller = PutController();

    final task = UploadPartsTask(
      token: token,
      partSize: options.partSize,
      uploadId: uploadId,
      maxPartsRequestNumber: options.maxPartsRequestNumber,
      resource: resource,
      key: options.key,
      controller: _controller,
    );

    _controller.addSendProgressListener(onSendProgress);

    manager.addTask(task);
    _currentWorkingTaskController = _controller;
    return task;
  }

  /// 创建文件，分片上传的最后一步
  CompletePartsTask _createCompleteParts(
    String uploadId,
    List<Part> parts,
  ) {
    final _controller = PutController();
    final task = CompletePartsTask(
      token: token,
      uploadId: uploadId,
      parts: parts,
      key: options.key,
      customVars: options.customVars,
      controller: _controller,
    );

    manager.addTask(task);
    _currentWorkingTaskController = _controller;
    return task;
  }
}
