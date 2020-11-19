part of 'config.dart';

abstract class HostProvider {
  Future<String> getUpHost({
    @required String accessKey,
    @required String bucket,
  });
}

class DefaultHostProvider extends HostProvider {
  final http = Dio();

  @override
  Future<String> getUpHost({
    @required String accessKey,
    @required String bucket,
  }) async {
    final protocol = Protocol.Https.value;

    final url = protocol +
        '://api.qiniu.com/v2/query?ak=' +
        accessKey +
        '&bucket=' +
        bucket;

    final res = await http.get<Map>(url);
    final host = res.data['up']['acc']['main'][0] as String;

    return protocol + '://' + host;
  }
}
