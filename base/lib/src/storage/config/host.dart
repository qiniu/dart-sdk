part of 'config.dart';

abstract class HostProvider {
  Future<String> getUpHost({required String token});
}

class DefaultHostProvider extends HostProvider {
  final http = Dio();

  @override
  Future<String> getUpHost({required String token}) async {
    final tokenInfo = Auth.parseToken(token);
    final putPolicy = tokenInfo.putPolicy;
    final protocol = Protocol.Https.value;

    if (putPolicy == null) {
      /// 非 upload token 没有 putPolicy 信息
      throw ArgumentError('invalid token');
    }

    final url = protocol +
        '://api.qiniu.com/v2/query?ak=' +
        tokenInfo.accessKey +
        '&bucket=' +
        putPolicy.getBucket();

    final res = await http.get<Map>(url);
    final host = res.data['up']['acc']['main'][0] as String;

    return protocol + '://' + host;
  }
}
