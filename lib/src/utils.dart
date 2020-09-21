// import 'auth/auth.dart';
// import 'config.dart';
// import 'storage.dart';

// /// 根据 [token] 获取其中的 Bucket 对应的 Region 的上传地址
// Future<String> getHostByToken(String token,
//     [Protocol protocol = Protocol.Http]) async {
//   final tokenInfo = Auth.parseToken(token);
//   final url = protocol.value +
//       '://api.qiniu.com/v2/query?ak=' +
//       tokenInfo.accessKey +
//       '&bucket=' +
//       tokenInfo.putPolicy.getBucket();

//   final res = await http.get(url);

//   return protocol.value + '://' + res.data['up']['acc']['main'][0];
// }
