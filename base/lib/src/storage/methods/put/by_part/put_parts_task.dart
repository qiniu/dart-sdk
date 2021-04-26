import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';

part 'cache_mixin.dart';
part 'complete_parts_task.dart';
part 'init_parts_task.dart';
part 'part.dart';
part 'upload_part_task.dart';
part 'upload_parts_task.dart';

/// 分片上传任务
class PutByPartTask extends RequestTask<PutResponse> {
  final File file;
  final String token;

  final int partSize;
  final int maxPartsRequestNumber;

  final String? key;

  /// 自定义变量，key 必须以 x: 开始
  final Map<String, String>? customVars;

  /// 设置为 0，避免子任务重试失败后 [PutByPartTask] 继续重试
  @override
  int get retryLimit => 0;

  PutByPartTask({
    required this.file,
    required this.token,
    required this.partSize,
    required this.maxPartsRequestNumber,
    this.key,
    this.customVars,
    PutController? controller,
  })  : assert(() {
          if (partSize < 1 || partSize > 1024) {
            throw RangeError.range(partSize, 1, 1024, 'partSize',
                'partSize must be greater than 1 and less than 1024');
          }
          return true;
        }()),
        super(controller: controller);

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
        message: '$file 已在上传队列中',
      );
    }

    // controller 被取消后取消当前运行的子任务
    controller?.cancelToken.whenCancel.then((_) {
      _currentWorkingTaskController?.cancel();
    });
  }

  @override
  void postReceive(PutResponse data) {
    _currentWorkingTaskController = null;
    super.postReceive(data);
  }

  @override
  Future<PutResponse> createTask() async {
    controller?.notifyStatusListeners(StorageStatus.Request);

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
        if (error.code == 612 || error.code == 400) {
          await initPartsTask.clearCache();
          await uploadParts.clearCache();
        }

        /// 如果服务端文件被删除了，重新上传
        if (error.code == 612) {
          controller?.notifyStatusListeners(StorageStatus.Retry);
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
    return target.file.path == file.path &&
        target.key == key &&
        target.file.lengthSync() == file.lengthSync();
  }

  /// 初始化上传信息，分片上传的第一步
  InitPartsTask _createInitParts() {
    final _controller = PutController();

    final task = InitPartsTask(
      file: file,
      token: token,
      key: key,
      controller: _controller,
    );

    manager.addTask(task);
    _currentWorkingTaskController = _controller;
    return task;
  }

  UploadPartsTask _createUploadParts(String uploadId) {
    final _controller = PutController();

    final task = UploadPartsTask(
      file: file,
      token: token,
      partSize: partSize,
      uploadId: uploadId,
      maxPartsRequestNumber: maxPartsRequestNumber,
      key: key,
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
      key: key,
      customVars: customVars,
      controller: _controller,
    );

    manager.addTask(task);
    _currentWorkingTaskController = _controller;
    return task;
  }
}
