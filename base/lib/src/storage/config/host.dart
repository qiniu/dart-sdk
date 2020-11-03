part of 'config.dart';

abstract class HostProvider {
  Future<String> getUpHost({@required String token});
}

class DefaultHostProvider extends HostProvider {
  final http = Dio();

  @override
  Future<String> getUpHost({@required String token}) async {
    final tokenInfo = Auth.parseUpToken(token);
    final putPolicy = tokenInfo.putPolicy;
    final protocol = Protocol.Https.value;

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
