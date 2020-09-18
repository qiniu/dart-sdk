import 'dart:convert';

class PutPolicy {
  String ak;
  String bucket;

  PutPolicy({this.ak, this.bucket});
}

PutPolicy getPutPolicy(String token) {
  final segments = token.split(':');
  // token 构造的差异参考：https://github.com/qbox/product/blob/master/kodo/auths/UpToken.md#admin-uptoken-authorization
  final ak = segments.length > 3 ? segments[1] : segments[0];
  // {"scope":"xxx","deadline":1600280416}
  Map data = jsonDecode((urlSafeBase64Decode(segments[segments.length - 1])));

  return PutPolicy(ak: ak, bucket: data['scope'].split(':')[0]);
}

String urlSafeBase64Decode(String url) {
  final _url = url.replaceAll(RegExp('_'), '/').replaceAll(RegExp('-'), '+');

  return String.fromCharCodes(base64.decode(_url));
}
