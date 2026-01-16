part of 'request_task.dart';

/// HostProvider 的包装类，提供首次请求失败时的重试逻辑
///
/// 当第一次获取上传域名时，如果所有域名都被冻结导致失败，
/// 此包装器会自动解冻一个域名并重试一次。
class _HostProvider extends HostProvider {
  final HostProvider _hostprovider;

  bool _hasGetUpHost = false;

  _HostProvider(this._hostprovider);

  @override
  Future<String> getUpHost({
    required String accessKey,
    required String bucket,
    bool accelerateUploading = false,
    bool transregional = false,
    int regionIndex = 0,
  }) async {
    var retryCount = 0;
    while (true) {
      try {
        final host = await _hostprovider.getUpHost(
          accessKey: accessKey,
          bucket: bucket,
          accelerateUploading: accelerateUploading,
          transregional: transregional,
          regionIndex: regionIndex,
        );
        _hasGetUpHost = true;
        return host;
      } on StorageError catch (error) {
        if (_hasGetUpHost) {
          rethrow;
        }
        if (error.type != StorageErrorType.NO_AVAILABLE_HOST) {
          rethrow;
        }
        if (retryCount >= 3) {
          rethrow;
        }
        // 如果第一次获取上传域名就失败，尝试解冻一个上传域名后重试一次
        _hostprovider.unfreezeOne();
        retryCount++;
      }
    }
  }

  @override
  void freezeHost(String host) {
    _hostprovider.freezeHost(host);
  }

  @override
  bool isFrozen(String host) {
    return _hostprovider.isFrozen(host);
  }

  @override
  void unfreezeOne() {
    _hostprovider.unfreezeOne();
  }
}

class RequestTaskManager extends TaskManager {
  late final Config config;

  RequestTaskManager({
    required this.config,
  });

  @override
  void addTask(covariant RequestTask task) {
    task.config = Config(
      hostProvider: _HostProvider(config.hostProvider),
      cacheProvider: config.cacheProvider,
      httpClientAdapter: config.httpClientAdapter,
      retryLimit: config.retryLimit,
    );
    super.addTask(task);
  }
}
