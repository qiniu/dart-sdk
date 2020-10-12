part of 'config.dart';

abstract class HostProvider {
  Future<String> getUpHostByToken(String token);
}

class DefaultHostProvider extends HostProvider {
  final http = Dio();

  Protocol protocol;

  DefaultHostProvider({this.protocol = Protocol.Https});

  @override
  Future<String> getUpHostByToken(String token) async {
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
