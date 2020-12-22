enum StorageStatus {
  None,

  /// 初始化任务
  Init,

  /// 请求准备发出的时候触发
  Request,

  /// 请求完成后触发
  Success,

  /// 请求被取消后触发
  Cancel,

  /// 请求出错后触发
  Error,

  /// 请求出错触发重试时触发
  Retry
}
