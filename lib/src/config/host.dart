part of 'config.dart';

abstract class AbstractHostProvider {
  Future<String> getHostByToken(String token, [Protocol protocol]);
}

class HostProvider extends AbstractHostProvider {
  final http = Dio();

  @override
  Future<String> getHostByToken(String token,
      [Protocol protocol = Protocol.Http]) async {
    final tokenInfo = Auth.parseToken(token);
    final url = protocol.value +
        '://api.qiniu.com/v2/query?ak=' +
        tokenInfo.accessKey +
        '&bucket=' +
        tokenInfo.putPolicy.getBucket();

    final res = await http.get<Map>(url);
    final host = res.data['up']['acc']['main'][0] as String;

    return protocol.value + '://' + host;
  }
}
