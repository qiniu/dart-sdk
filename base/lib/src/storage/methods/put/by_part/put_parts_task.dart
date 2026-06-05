import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../../qiniu_sdk_base.dart';
import '../../../task/task_manager.dart';
import '../../../resource/resource.dart';
import '../../../task/request_task.dart';
import '../../../task/request_task_controller.dart';

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

  /// 当前正在使用的区域索引
  int _regionIndex = 0;

  /// 单区域重试次数
  int _singleRegionRetryCount = 0;

  /// 上次错误
  Object? _error;

  /// 是否应该重试，本任务只处理区域间的重试
  bool _shouldRetry = true;

  /// 最近一次 [InitPartsTask]（成功 / 失败均会赋值），
  /// 用于在错误清理与最终成功路径上清缓存。
  InitPartsTask? _lastInitPartsTask;

  /// 最近一次 [UploadPartsTask]，用途同上
  UploadPartsTask? _lastUploadPartsTask;

  PutByPartTask({
    required Config config,
    required this.resource,
    required this.token,
    required this.options,
  }) : super(config, controller: options.controller);

  RequestTaskController? _currentWorkingTaskController;

  @override
  String taskID() {
    return resource.id;
  }

  @override
  Future<void> preStart() async {
    // 顶层任务：重置进度基线，避免复用同一 Controller 发起第二次上传时
    // 进度被 `percent <= _lastNotified...` 过滤掉。retry 路径（preRestart）
    // 不调用，保持进度单调性。
    controller?.resetProgressBaseline();
    await super.preStart();

    // controller 被取消后取消当前运行的子任务
    controller?.cancelToken.whenCancel.then((_) {
      _currentWorkingTaskController?.cancel();
    });

    controller?.notifyStatusListeners(StorageStatus.Request);
  }

  @override
  Future<void> postReceive(PutResponse data) async {
    await resource.close();
    await super.postReceive(data);
    _currentWorkingTaskController = null;
  }

  @override
  Future<void> postError(Object error, {bool complete = false}) async {
    await resource.close();
    await super.postError(error, complete: complete);
  }

  @override
  Future<void> preRestart() async {
    controller?.notifyStatusListeners(StorageStatus.Retry);
    await super.preRestart();
  }

  @override
  bool showRetry(Object error) {
    return _shouldRetry;
  }

  @override
  Future<PutResponse> createTask() async {
    try {
      await resource.open();
      final initParts = await _runInit(_regionIndex);
      final parts = await _runUpload(_regionIndex, initParts.uploadId);
      final response = await _runComplete(
        _regionIndex,
        initParts.uploadId,
        parts,
      );

      /// 上传完成，清除缓存
      await _lastInitPartsTask?.clearCache();
      await _lastUploadPartsTask?.clearCache();
      return response;
    } catch (error) {
      return await _handleError(error);
    }
  }

  /// 初始化分片上传，返回 uploadId
  Future<InitParts> _runInit(int regionIndex) async {
    final task = _createInitPartsTask(regionIndex);
    _lastInitPartsTask = task;
    _currentWorkingTaskController = task.controller;
    final result = await TaskManager.runStandalone<InitParts>(task);

    /// 初始化任务完成后也告诉外部一个进度
    controller?.notifyProgressListeners(0.002);
    return result;
  }

  /// 上传所有分片
  Future<List<Part>> _runUpload(int regionIndex, String uploadId) async {
    final task = _createUploadPartsTask(regionIndex, uploadId);
    _lastUploadPartsTask = task;
    _currentWorkingTaskController = task.controller;
    return await TaskManager.runStandalone(task);
  }

  /// 合并分片
  Future<PutResponse> _runComplete(
    int regionIndex,
    String uploadId,
    List<Part> parts,
  ) async {
    final task = _createCompletePartsTask(regionIndex, uploadId, parts);
    _currentWorkingTaskController = task.controller;
    return await TaskManager.runStandalone(task);
  }

  /// 错误分发：按错误类型决定 清理缓存 / 切区域重试 / 终止重试 / 单区域内重试
  Future<PutResponse> _handleError(Object error) async {
    if (error is! StorageError) {
      // 不是 StorageError，直接抛出
      _shouldRetry = false;
      throw error;
    }

    /// 满足以下两种情况清理缓存：
    /// 1、如果服务端临时文件数据被删除了，清除本地缓存
    /// 2、源读取异常，之前上传的数据无效
    /// 不切换区域进行重试
    if (isCtxExpiedError(error.code) ||
        error.type == StorageErrorType.RESOURCE_READ_EXCEPTION) {
      await _lastInitPartsTask?.clearCache();
      await _lastUploadPartsTask?.clearCache();
      if (_singleRegionRetryCount > 0) {
        // 每个区域只重试一次
        _shouldRetry = false;
      } else {
        _singleRegionRetryCount++;
      }
      throw error;
    }

    if (error.type == StorageErrorType.NO_AVAILABLE_REGION) {
      // 没有可用的区域了，停止重试
      _shouldRetry = false;
      throw _error ?? error;
    }

    if (error.type == StorageErrorType.CANCEL ||
        !isRegionRetryableError(error)) {
      // 没有可用的服务器了，停止重试
      _shouldRetry = false;
      throw error;
    }

    // 切换区域重试，重置单区域重试次数
    _regionIndex++;
    _singleRegionRetryCount = 0;
    _error = error;
    throw error;
  }

  /// 初始化上传信息，分片上传的第一步
  InitPartsTask _createInitPartsTask(int regionIndex) {
    final controller = PutController();

    final task = InitPartsTask(
      config: config,
      resource: resource,
      token: token,
      key: options.key,
      controller: controller,
      accelerateUploading: options.accelerateUploading,
      regionIndex: regionIndex,
    );

    return task;
  }

  UploadPartsTask _createUploadPartsTask(int regionIndex, String uploadId) {
    final controller = PutController();

    final task = UploadPartsTask(
      config: config,
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
    return task;
  }

  /// 创建文件，分片上传的最后一步
  CompletePartsTask _createCompletePartsTask(
    int regionIndex,
    String uploadId,
    List<Part> parts,
  ) {
    final controller = PutController();
    final task = CompletePartsTask(
      config: config,
      token: token,
      uploadId: uploadId,
      parts: parts,
      key: options.key ?? resource.name,
      mimeType: options.mimeType,
      customVars: options.customVars,
      controller: controller,
      accelerateUploading: options.accelerateUploading,
      regionIndex: regionIndex,
    );

    return task;
  }
}
