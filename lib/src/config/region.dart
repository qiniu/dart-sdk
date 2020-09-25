part of 'config.dart';

enum Region { Z0, Z1, Z2, Na0, As0 }

final Map regionMap = {
  Region.Z0: 'upload.qiniup.com',
  Region.Z1: 'upload-z1.qiniup.com',
  Region.Z2: 'upload-z2.qiniup.com',
  Region.Na0: 'upload-na0.qiniup.com',
  Region.As0: 'upload-as0.qiniup.com'
};

abstract class AbstractRegionProvider {
  String getHostByRegion(region);

  Future<String> getHostByToken(String token, [Protocol protocol]);
}

class RegionProvider extends AbstractRegionProvider {
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

    return protocol.value + '://' + res.data['up']['acc']['main'][0];
  }
}
