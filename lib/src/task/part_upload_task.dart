// import 'dart:io';
// import 'dart:typed_data';

// import 'package:qiniu_sdk_base/src/apis/upload_parts.dart';
// import 'package:qiniu_sdk_base/src/auth/auth.dart';

// import '../auth/put_policy.dart';

// /// 上传块任务
// class UploadPartsTask {
//   Uint8List block;
//   File file;
//   String key;
//   String token;
//   PutPolicy putPolicy;
//   String host;
//   final UploadPartsApi _uploadPartsApi;

//   /// 切片大小。单位 MB，默认 4 MB
//   int chunkSize;
//   UploadPartsTask(
//       {this.block,
//       this.key,
//       this.chunkSize = 4,
//       this.file,
//       this.token,
//       this.host})
//       : _uploadPartsApi = UploadPartsApi(host: host, token: token),
//         putPolicy = Auth.parseToken(token).putPolicy;

//   /// 整个上传过程需要用到的 id
//   String _uploadId;
//   final List<Part> _parts = [];

//   void start() async {
//     final initParts = await _uploadPartsApi.initParts(
//         bucket: putPolicy.getBucket(), key: key);
//     _uploadId = initParts.uploadId;

//     _uploadParts(0);
//   }

//   void _uploadParts(int partNumber) async {
//     final uploadParts = await _uploadPartsApi.uploadParts(
//         bucket: putPolicy.getBucket(),
//         key: key,
//         uploadId: _uploadId,
//         partNumber: partNumber);

//     _parts.add(Part(partNumber: partNumber, etag: uploadParts.etag));
//   }

//   void stop() {
//     _uploadPartsApi.completeParts(
//         bucket: putPolicy.getBucket(),
//         key: key,
//         uploadId: _uploadId,
//         parts: _parts,
//         fileLength: file.lengthSync());
//   }

//   void resume() {}
// }
