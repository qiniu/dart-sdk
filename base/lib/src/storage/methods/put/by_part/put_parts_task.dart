import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import '../../../../../qiniu_sdk_base.dart';
import '../../../resource/resource.dart';

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
  int regionIndex = 0;

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

    return await _doUploading();
  }

  Future<PutResponse> _doUploading() async {
    InitPartsTask? initPartsTask;
    InitParts? initParts;
    UploadPartsTask? uploadPartsTask;
    while (true) {
      try {
        await resource.open();

        initPartsTask = _createInitParts();
        initParts = await initPartsTask.future;

        // 初始化任务完成后也告诉外部一个进度
        controller?.notifyProgressListeners(0.002);

        uploadPartsTask = _createUploadParts(
          initParts.uploadId,
        );

        try {
          final parts = await uploadPartsTask.future;
          final putResponse = await _createCompleteParts(
            initParts.uploadId,
            parts,
          ).future;

          /// 上传完成，清除缓存
          await initPartsTask.clearCache();
          await uploadPartsTask.clearCache();
          return putResponse;
        } catch (error) {
          // 拿不到 initPartsTask 和 uploadParts 的引用，所以不放到 postError 去
          if (error is StorageError) {
            /// 满足以下两种情况清理缓存：
            /// 1、如果服务端文件被删除了，清除本地缓存
            /// 2、如果 PartNumber 不符合要求，顺序不对等原因导致的参数不对(400)
            if (error.code == 400 || error.code == 612) {
              await Future.wait(
                [initPartsTask.clearCache(), uploadPartsTask.clearCache()],
              );
            }

            /// 如果服务端文件被删除了，重新上传
            if (error.code == 612) {
              controller?.notifyStatusListeners(StorageStatus.Retry);
              await resource.close();
              continue;
            }
          }

          rethrow;
        }
      } on StorageError catch (error) {
        if (error.type == StorageErrorType.NO_AVAILABLE_HOST) {
          regionIndex += 1;
          await Future.wait([
            if (initPartsTask != null) initPartsTask.clearCache(),
            if (uploadPartsTask != null) uploadPartsTask.clearCache(),
          ]);
        } else {
          rethrow;
        }
      }
    }
  }

  bool isEquals(PutByPartTask target) {
    return target.resource.id == resource.id;
  }

  /// 初始化上传信息，分片上传的第一步
  InitPartsTask _createInitParts() {
    final controller = PutController();

    final task = InitPartsTask(
      resource: resource,
      token: token,
      key: options.key,
      controller: controller,
      accelerateUploading: options.accelerateUploading,
      regionIndex: regionIndex,
    );

    manager.addTask(task);
    _currentWorkingTaskController = controller;
    return task;
  }

  UploadPartsTask _createUploadParts(String uploadId) {
    final controller = PutController();

    final task = UploadPartsTask(
      token: token,
      partSize: options.partSize,
      uploadId: uploadId,
      maxPartsRequestNumber: options.maxPartsRequestNumber,
      resource: resource,
      controller: controller,
      accelerateUploading: options.accelerateUploading,
      regionIndex: regionIndex,
    );

    controller.addSendProgressListener(onSendProgress);

    manager.addTask(task);
    _currentWorkingTaskController = controller;
    return task;
  }

  /// 创建文件，分片上传的最后一步
  CompletePartsTask _createCompleteParts(String uploadId, List<Part> parts) {
    final controller = PutController();
    final task = CompletePartsTask(
      token: token,
      uploadId: uploadId,
      parts: parts,
      key: resource.name,
      mimeType: options.mimeType,
      customVars: options.customVars,
      controller: controller,
      accelerateUploading: options.accelerateUploading,
      regionIndex: regionIndex,
    );

    manager.addTask(task);
    _currentWorkingTaskController = controller;
    return task;
  }
}
