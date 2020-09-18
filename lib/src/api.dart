import 'config.dart';
import 'storage.dart';
import 'utils.dart';

/// 根据 [token] 获取其中的 Bucket 对应的 Region 的上传地址
Future<String> getHostByToken(String token,
    [Protocol protocol = Protocol.Http]) async {
  final putPolicy = getPutPolicy(token);
  final url = protocol.value +
      '://api.qiniu.com/v2/query?ak=' +
      putPolicy.ak +
      '&bucket=' +
      putPolicy.bucket;

  final res = await http.get(url);

  return protocol.value + '://' + res.data['up']['acc']['main'][0];
}
