class PutByPartOptions {
  /// 资源名
  /// 如果不传则后端自动生成
  final String key;

  /// 切片大小，单位 MB
  ///
  /// 超出 [partSize] 的文件大小会把每片按照 [partSize] 的大小切片并上传
  /// 默认 4MB，最小不得小于 1MB，最大不得大于 1024 MB
  final int partSize;

  final int maxPartsRequestNumber;

  PutByPartOptions({
    this.key,
    this.partSize,
    this.maxPartsRequestNumber,
  }) {
    if (partSize < 1 || partSize > 1024) {
      throw RangeError.range(partSize, 1, 1024, 'partSize',
          'partSize must be greater than 1 and less than 1024');
    }
  }
}
