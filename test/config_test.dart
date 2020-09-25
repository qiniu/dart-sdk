import 'package:qiniu_sdk_base/src/config/config.dart';
import 'package:test/test.dart';

import 'config.dart';

void main() {
  configEnv();

  test('RegionProvider should works well.', () async {
    final regionProvider = RegionProvider();

    final zoHost = regionProvider.getHostByRegion(Region.Z0);

    expect(zoHost, 'https://upload.qiniup.com');

    final hostInToken = await regionProvider.getHostByToken(token);

    // 根据传入的 token 的 bucket 对应的区域，需要对应的修改这里
    expect(hostInToken, 'http://' + regionMap[Region.Z0]);
  });
}
