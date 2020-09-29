import 'dart:convert';
import 'package:meta/meta.dart';
import 'package:crypto/crypto.dart';
import './put_policy.dart';

class TokenInfo {
  final String accessKey;
  final PutPolicy putPolicy;
  const TokenInfo(this.accessKey, this.putPolicy);
}

/// 提供用于鉴权的相关功能。
///
/// 安全机制文档请参阅
///
/// https://developer.qiniu.com/kodo/manual/1644/security
class Auth {
  /// 鉴权所需的 [accessKey]。
  ///
  /// 如何生成以及查看请参阅：
  ///
  /// http://developer.qiniu.com/article/developer/security/index.html
  ///
  /// 使用须知请查看：
  ///
  /// https://developer.qiniu.com/kodo/kb/1334/the-access-key-secret-key-encryption-key-safe-use-instructions
  final String accessKey;

  /// 鉴权所需的 [secretKey]。
  ///
  /// 如何生成以及查看、使用等请参阅 [accessKey] 的说明
  final String secretKey;

  const Auth({
    @required this.accessKey,
    @required this.secretKey,
  })  : assert(accessKey != null),
        assert(secretKey != null);

  /// 根据上传策略生成上传使用的 Token。
  ///
  /// 具体的上传策略说明请参考 [PutPolicy] 模块
  String generateUploadToken({
    @required PutPolicy putPolicy,
  }) {
    assert(putPolicy != null);

    var data = jsonEncode(putPolicy);
    var encodedPutPolicy = base64Url.encode(utf8.encode(data));
    var baseToken = generateAccessToken(bytes: utf8.encode(encodedPutPolicy));
    return '$baseToken:$encodedPutPolicy';
  }

  /// 生成针对私有空间资源的下载 Token。
  ///
  /// [key] 为对象的名称
  /// [deadline] 有效时间，单位为秒，例如 1451491200
  /// [bucketDomain] 空间绑定的域名，例如 http://test.bucket.com
  String generateDownloadToken({
    @required String key,
    @required int deadline,
    @required String bucketDomain,
  }) {
    assert(key != null);
    assert(deadline != null);
    assert(bucketDomain != null);

    var downloadURL = '$bucketDomain/$key?e=$deadline';
    return generateAccessToken(bytes: utf8.encode(downloadURL));
  }

  /// 根据数据签名，生成 Token（用于接口的访问鉴权）。
  ///
  /// 访问七牛的接口需要对请求进行签名, 该方法提供 Token 签发服务
  String generateAccessToken({@required List<int> bytes}) {
    assert(bytes != null);
    var hmacEncoder = Hmac(sha1, utf8.encode(secretKey));

    var sign = hmacEncoder.convert(bytes);
    var encodedSign = base64Url.encode(sign.bytes);
    return '$accessKey:$encodedSign';
  }

  /// 解析 token 信息。
  ///
  /// 从 Token 字符串中解析 [accessKey]、[PutPolicy] 信息
  static TokenInfo parseToken({@required String token}) {
    assert(token != null && token != '');
    var segments = token.split(':');
    if (segments.length < 2) {
      throw ArgumentError('invalid token');
    }

    PutPolicy putPolicy;
    var accessKey = segments.first;

    /// 具体的 token 信息可以参考这里。
    ///
    /// https://github.com/qbox/product/blob/master/kodo/auths/UpToken.md#admin-uptoken-authorization
    if (segments.length >= 3) {
      if (segments.last == '') {
        throw ArgumentError('invalid token');
      }

      putPolicy = PutPolicy.fromJson(jsonDecode(
        String.fromCharCodes(
          base64Url.decode(
            segments.last,
          ),
        ),
      ) as Map<String, dynamic>);
    }

    return TokenInfo(accessKey, putPolicy);
  }
}
