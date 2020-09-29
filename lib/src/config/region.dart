part of 'config.dart';

enum Region { Z0, Z1, Z2, Na0, As0 }

final Map<Region, String> regionMap = {
  Region.Z0: 'upload.qiniup.com',
  Region.Z1: 'upload-z1.qiniup.com',
  Region.Z2: 'upload-z2.qiniup.com',
  Region.Na0: 'upload-na0.qiniup.com',
  Region.As0: 'upload-as0.qiniup.com'
};

abstract class AbstractHostProvider {
  String getHostByRegion(region);

  Future<String> getHostByToken(String token, [Protocol protocol]);
}

class HostProvider extends AbstractHostProvider {
  final http = Dio();

  @override
  String getHostByRegion(region) {
    return Protocol.Http.value + '://' + regionMap[region];
  }

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
