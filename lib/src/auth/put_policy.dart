import 'package:meta/meta.dart';

/// 上传策略
///
/// 关于具体信息查看
///
/// https://developer.qiniu.com/kodo/manual/1206/put-policy
class PutPolicy {
  /// 指定上传的目标资源空间 Bucket 和资源键 Key（最大为 750 字节）。
  ///
  /// 有三种格式：
  /// <Bucket> 表示允许用户上传文件到指定的 Bucket，在这种格式下文件只能新增。
  /// <Bucket>:<Key> 表示只允许用户上传指定 Key 的文件。在这种格式下文件默认允许修改。
  /// <Bucket>:<KeyPrefix> 表示只允许用户上传指定以 KeyPrefix 为前缀的文件。
  /// 具体信息一定请查看上述的上传策略文档！
  final String scope;

  /// 获取 Bucket。
  ///
  /// 从 [scope] 中获取 Bucket。
  String getBucket() {
    return scope.split(':').first;
  }

  /// 若为 1，表示允许用户上传以 [scope] 的 KeyPrefix 为前缀的文件。
  final int isPrefixalScope;

  /// 上传凭证有效截止时间。
  ///
  /// Unix 时间戳，单位为秒，
  /// 该截止时间为上传完成后，在七牛空间生成文件的校验时间， 而非上传的开始时间，
  /// 一般建议设置为上传开始时间 + 3600s。
  final int deadline;

  /// 限制为新增文件。
  ///
  /// 如果设置为非 0 值，则无论 [scope] 设置为什么形式，仅能以新增模式上传文件。
  final int insertOnly;

  /// 唯一属主标识。
  ///
  /// 特殊场景下非常有用，例如根据 App-Client 标识给图片或视频打水印。
  final String endUser;

  /// Web 端文件上传成功后，浏览器执行 303 跳转的 URL。
  ///
  /// 文件上传成功后会跳转到 <[returnUrl]>?upload_ret=<QueryString>
  /// 其中 <QueryString> 包含 [returnBody] 内容。
  /// 如不设置 [returnUrl]，则直接将 [returnBody] 的内容返回给客户端。
  final String returnUrl;

  /// [returnBody] 声明服务端的响应格式。
  ///
  /// 可以使用 <魔法变量> 和 <自定义变量>，必须是合法的 JSON 地址，
  /// 关于 <魔法变量> 请参阅：
  ///
  /// https://developer.qiniu.com/kodo/manual/1235/vars#magicvar
  ///
  /// 关于 <自定义变量> 请参阅：
  ///
  ///  https://developer.qiniu.com/kodo/manual/1235/vars#xvar
  final String returnBody;

  /// 上传成功后，七牛云向业务服务器发送 POST 请求的 URL。
  final String callbackUrl;

  /// 上传成功后，七牛云向业务服务器发送回调通知时的 Host 值。
  ///
  /// 与 [callbackUrl] 配合使用，仅当设置了 [callbackUrl] 时才有效。
  final String callbackHost;

  /// 上传成功后发起的回调请求。
  ///
  /// 七牛云向业务服务器发送 Content-Type: application/x-www-form-urlencoded 的 POST 请求，
  /// 例如:{"key":"$(key)","hash":"$(etag)","w":"$(imageInfo.width)","h":"$(imageInfo.height)"}，
  /// 可以使用 <魔法变量> 和 <自定义变量>。
  final String callbackBody;

  /// 上传成功后发起的回调请求的 Content-Type。
  ///
  /// 默认为 application/x-www-form-urlencoded，也可设置为 application/json。
  final String callbackBodyType;

  /// 资源上传成功后触发执行的预转持久化处理指令列表。
  ///
  /// [fileType] = 2（上传归档存储文件）时，不支持使用该参数，
  /// 每个指令是一个 API 规格字符串，多个指令用 ; 分隔，
  /// 可以使用 <魔法变量> 和 <自定义变量>，
  /// 具体信息可以查看文档：
  ///
  /// https://developer.qiniu.com/kodo/manual/1206/put-policy#persistentOps
  ///
  /// 示例：
  ///
  /// https://developer.qiniu.com/kodo/manual/1206/put-policy#demo
  final String persistentOps;

  /// 接收持久化处理结果通知的 URL。
  ///
  /// 必须是公网上可以正常进行 POST 请求并能响应 HTTP/1.1 200 OK 的有效 URL，
  /// 该 URL 获取的内容和持久化处理状态查询的处理结果一致，
  /// 发送 body 格式是 Content-Type 为 application/json 的 POST 请求，
  /// 需要按照读取流的形式读取请求的 body 才能获取。
  final String persistentNotifyUrl;

  /// 转码队列名。
  ///
  /// 资源上传成功后，触发转码时指定独立的队列进行转码，
  /// 为空则表示使用公用队列，处理速度比较慢。建议使用专用队列。
  final String persistentPipeline;

  /// [saveKey] 的优先级设置。
  ///
  /// 该设置为 true 时，[saveKey] 不能为空，会忽略客户端指定的 Key，强制使用 [saveKey] 进行文件命名。
  /// 参数不设置时，默认值为 false。
  final String forceSaveKey;

  ///	自定义资源名。
  ///
  /// 支持<魔法变量>和<自定义变量>, [forceSaveKey] 为 false 时，
  /// 这个字段仅当用户上传的时候没有主动指定 key 时起作用，
  /// [forceSaveKey] 为 true 时，将强制按这个字段的格式命名。
  final String saveKey;

  /// 限定上传文件大小最小值，单位 Byte。
  final int fsizeMin;

  /// 限定上传文件大小最大值，单位 Byte。
  ///
  /// 超过限制上传文件大小的最大值会被判为上传失败，返回 413 状态码。
  final int fsizeLimit;

  /// 开启 MimeType 侦测功能。
  final int detectMime;

  /// 限定用户上传的文件类型。
  final String mimeLimit;

  /// 文件存储类型
  ///
  /// 0 为标准存储（默认），
  /// 1 为低频存储，
  /// 2 为归档存储。
  final int fileType;

  const PutPolicy({
    @required this.scope,
    @required this.deadline,
    this.isPrefixalScope,
    this.insertOnly,
    this.endUser,
    this.returnUrl,
    this.returnBody,
    this.callbackUrl,
    this.callbackHost,
    this.callbackBody,
    this.callbackBodyType,
    this.persistentOps,
    this.persistentNotifyUrl,
    this.persistentPipeline,
    this.forceSaveKey,
    this.saveKey,
    this.fsizeMin,
    this.fsizeLimit,
    this.detectMime,
    this.mimeLimit,
    this.fileType,
  })  : assert(scope != null),
        assert(deadline != null);

  Map<String, dynamic> toJson() {
    return {
      'scope': scope,
      'isPrefixalScope': isPrefixalScope,
      'deadline': deadline,
      'insertOnly': insertOnly,
      'endUser': endUser,
      'returnUrl': returnUrl,
      'returnBody': returnBody,
      'callbackUrl': callbackUrl,
      'callbackHost': callbackHost,
      'callbackBody': callbackBody,
      'callbackBodyType': callbackBodyType,
      'persistentOps': persistentOps,
      'persistentNotifyUrl': persistentNotifyUrl,
      'persistentPipeline': persistentPipeline,
      'forceSaveKey': forceSaveKey,
      'saveKey': saveKey,
      'fsizeMin': fsizeMin,
      'fsizeLimit': fsizeLimit,
      'detectMime': detectMime,
      'mimeLimit': mimeLimit,
      'fileType': fileType,
    }..removeWhere((key, value) => value == null);
  }

  factory PutPolicy.fromJson(Map<String, dynamic> json) {
    return PutPolicy(
      scope: json['scope'],
      deadline: json['deadline'],
      isPrefixalScope: json['isPrefixalScope'],
      insertOnly: json['insertOnly'],
      endUser: json['endUser'],
      returnUrl: json['returnUrl'],
      returnBody: json['returnBody'],
      callbackUrl: json['callbackUrl'],
      callbackHost: json['callbackHost'],
      callbackBody: json['callbackBody'],
      callbackBodyType: json['callbackBodyType'],
      persistentOps: json['persistentOps'],
      persistentNotifyUrl: json['persistentNotifyUrl'],
      persistentPipeline: json['persistentPipeline'],
      forceSaveKey: json['forceSaveKey'],
      saveKey: json['saveKey'],
      fsizeMin: json['fsizeMin'],
      fsizeLimit: json['fsizeLimit'],
      detectMime: json['detectMime'],
      mimeLimit: json['mimeLimit'],
      fileType: json['fileType'],
    );
  }
}
