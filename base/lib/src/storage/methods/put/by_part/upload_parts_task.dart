part of 'put_parts_task.dart';

// 批处理上传 parts 的任务，为 [CompletePartsTask] 提供 [Part]
class UploadPartsTask extends RequestTask<List<Part>> with CacheMixin {
  final String token;
  final String uploadId;
  final bool accelerateUploading;
  final int regionIndex;

  final int partSize;
  final int maxPartsRequestNumber;

  @override
  late final String _cacheKey;

  /// 文件总共被拆分的分片数
  late final int _totalPartCount;

  /// 上传成功后把 part 信息存起来
  final Map<int, Part> _uploadedPartMap = {};

  /// 处理分片上传任务的 UploadPartTask 的控制器
  final List<RequestTaskController> _uploadPartTaskControllers = [];

  /// 每个 partNumber 上次回调时的 percent，用于算 delta。
  final Map<int, _PartProgress> _partProgressMap = {};

  /// 任一子任务失败时保存错误，用于取消其他运行中的子任务并阻止后续上传
  Object? _error;

  /// 剩余多少被允许的请求数
  late int _idleRequestNumber;

  /// 当前正在上传的 partNumber，初始值为 0，上传第一片时会自增到 1，以此类推
  int _uploadingPartIndex = 0;

  /// 是否已经读完资源流了，读完了就不会再有新的分片需要上传了，防止开始计算的分片数和实际上传的分片数不一致导致死循环
  bool _hasReadAllResourceStream = false;

  final Resource resource;

  UploadPartsTask({
    required Config config,
    required this.token,
    required this.uploadId,
    required this.partSize,
    required this.maxPartsRequestNumber,
    required this.resource,
    PutController? controller,
    this.accelerateUploading = false,
    this.regionIndex = 0,
  }) : super(config, controller: controller);

  @override
  bool showRetry(Object error) {
    return false;
  }

  @override
  Future<void> preStart() async {
    await super.preStart();
    // 当前 controller 被取消后，所有运行中的子任务都需要被取消
    controller?.cancelToken.whenCancel.then((_) {
      cancelWorkingUploadPartTasks();
    });

    _idleRequestNumber = maxPartsRequestNumber;
    if (_idleRequestNumber <= 0) {
      throw StorageError(
        type: StorageErrorType.UNKNOWN,
        message:
            'maxPartsRequestNumber must be >= 1, got $maxPartsRequestNumber',
      );
    }
    _totalPartCount = (resource.length / resource.chunkSize).ceil();
    final keyList = [
      'region/$regionIndex',
      'resource_id/${resource.id}',
      'upload_id/$uploadId',
      'key/${resource.name}',
      'part_size/$partSize',
    ];
    _cacheKey = 'qiniu_dart_sdk_upload_parts_task@[${keyList.join("/")}]';
  }

  Future<void> storeUploadedPart() async {
    if (_uploadedPartMap.isEmpty) {
      return;
    }

    try {
      await setCache(jsonEncode(_uploadedPartMap.values.toList()));
    } catch (_) {
      /// 保存失败不影响正常流程，所以 catch 掉错误
    }
  }

  // 从缓存恢复已经上传的 part
  Future<void> recoverUploadedPart() async {
    try {
      final cachedData = await getCache();
      if (cachedData == null) return;

      final cachedList = (json.decode(cachedData) as List<dynamic>)
          .map((dynamic item) => Part.fromJson(item as Map<String, dynamic>))
          .toList();

      for (final part in cachedList) {
        _uploadedPartMap[part.partNumber] = part;
      }
    } catch (_) {
      // 缓存数据损坏，按无缓存处理
    }
  }

  void cancelWorkingUploadPartTasks() {
    for (final controller in _uploadPartTaskControllers) {
      controller.cancel();
    }
  }

  @override
  Future<List<Part>> createTask() async {
    /// 如果已经取消了，直接报错
    // ignore: null_aware_in_condition
    if (controller != null && controller!.isCancelled) {
      throw StorageError(type: StorageErrorType.CANCEL);
    }

    controller?.notifyStatusListeners(StorageStatus.Request);

    // 尝试恢复缓存，如果有
    await recoverUploadedPart();
    // 上传分片
    await _uploadParts();
    return _uploadedPartMap.values.toList();
  }

  // 从指定的分片位置往后上传切片
  Future<void> _uploadParts() async {
    // 其他子任务已失败，不再继续
    if (_error != null) {
      return;
    }

    final taskFutures = <Future<void>>[];

    /// 本次需要创建的任务个数 = min(剩余被允许的请求数, 总分片数 - 已经上传的分片数)
    final tasksLength =
        min(_idleRequestNumber, _totalPartCount - _uploadingPartIndex);

    while (taskFutures.length < tasksLength &&
        _uploadingPartIndex < _totalPartCount) {
      // partNumber 按照后端要求必须从 1 开始
      final partNumber = ++_uploadingPartIndex;

      bool isReadStream = false;
      // [resource.stream] 是 broadcast stream，每次 `await for` 新订阅都会
      // 从当前 offset emit 一个 chunk 后立刻自然结束本次订阅，
      // 下一次 `await for` 继续接力——这是 [Resource] 对外的"分次拉取"协议。
      await for (final bytes in resource.stream) {
        isReadStream = true;

        // 跳过上传过的分片
        final uploadedPart = _uploadedPartMap[partNumber];
        final partProgress = _PartProgress(
          partNumber: partNumber,
          size: bytes.length.toDouble(),
        );
        if (uploadedPart != null) {
          partProgress.percent = 1.0;
          _partProgressMap[partNumber] = partProgress;
          notifyProgress();
        } else {
          final future = _uploadPartByPartNumber(bytes, partNumber);
          taskFutures.add(future);
          _partProgressMap[partNumber] = partProgress;
        }
        break;
      }
      if (!isReadStream) {
        // 资源流已经读完了
        _hasReadAllResourceStream = true;
        break;
      }
    }

    try {
      await Future.wait<void>(taskFutures);
    } catch (e) {
      /// 有分片执行失败
      /// 已经有其他分片失败了，不再重复设置错误状态
      if (_error != null) {
        return;
      }

      _error ??= e;

      if (e is StorageError && e.type != StorageErrorType.CANCEL) {
        /// 取消正在执行的分片上传任务，取消错误从上往下传递，不需要在这里再次取消
        cancelWorkingUploadPartTasks();
      }

      rethrow;
    }

    /// 检查任务是否已经完成
    if (_uploadedPartMap.length == _totalPartCount) {
      return;
    }

    /// 资源读取大于预期
    if (_uploadedPartMap.length > _totalPartCount) {
      throw StorageError(
        type: StorageErrorType.RESOURCE_READ_EXCEPTION,
        message:
            'Unexpected error: uploaded part count is greater than total part count',
      );
    }

    /// 资源读取少于预期
    if (_hasReadAllResourceStream) {
      throw StorageError(
        type: StorageErrorType.RESOURCE_READ_EXCEPTION,
        message:
            'Unexpected error: all resource stream has been read but uploaded size is less than total size',
      );
    }

    /// 上传下一片
    await _uploadParts();
  }

  Future<void> _uploadPartByPartNumber(
    List<int> bytes,
    int partNumber,
  ) async {
    _idleRequestNumber--;
    final controller = PutController();
    _uploadPartTaskControllers.add(controller);

    final task = UploadPartTask(
      config: config,
      token: token,
      bytes: bytes,
      uploadId: uploadId,
      byteLength: bytes.length,
      partNumber: partNumber,
      partSize: partSize,
      key: resource.name,
      controller: controller,
      accelerateUploading: accelerateUploading,
      regionIndex: regionIndex,
    );

    controller.addSendProgressListener((percent) {
      final partProgress = _partProgressMap[partNumber];
      if (partProgress == null) {
        return;
      }
      partProgress.percent = percent;
      notifyProgress();
    });

    final data = await TaskManager.runStandalone(task);

    _idleRequestNumber++;
    _uploadedPartMap[partNumber] =
        Part(partNumber: partNumber, etag: data.etag);
    _uploadPartTaskControllers.remove(controller);
    final partProgress = _partProgressMap[partNumber];
    if (partProgress != null) {
      partProgress.percent = 1.0;
    }
    notifyProgress();

    await storeUploadedPart();
  }

  void notifyProgress() {
    double sentBytes = 0;
    for (final partProgress in _partProgressMap.values) {
      sentBytes += partProgress.sentSize;
    }
    final percent = resource.length > 0
        ? sentBytes.toDouble() / resource.length.toDouble()
        : 0;
    onSendProgress(percent.toDouble());
  }
}
