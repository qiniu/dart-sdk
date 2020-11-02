import 'dart:io';

import 'package:qiniu_sdk_base/qiniu_sdk_base.dart' as base;

import './controller.dart';

export 'package:qiniu_sdk_base/qiniu_sdk_base.dart' show RequestStatus;

export './controller.dart';

class Storage {
  base.Storage baseStore;
  Storage({base.Config config}) : baseStore = base.Storage(config: config);

  PutController<base.PutResponse> putFile(
    File file,
    String token, {
    base.PutOptions options,
  }) {

    final ctrl = baseStore.putFile(file, token, options: options);
    return PutController(ctrl.task);
  }

  /// 单文件上传
  PutController<base.PutResponse> putFileBySingle(
    File file,
    String token, {
    base.PutBySingleOptions options,
  }) {
    final ctrl = baseStore.putFileBySingle(file, token, options: options);
    return PutController(ctrl.task);
  }

  /// 分片上传
  PutController<base.PutResponse> putFileByPart(
    File file,
    String token, {
    base.PutByPartOptions options,
  }) {
    final ctrl = baseStore.putFileByPart(file, token, options: options);
    return PutController(ctrl.task);
  }
}
