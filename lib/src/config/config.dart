import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/src/auth/auth.dart';
import 'package:qiniu_sdk_base/src/task/task_manager.dart';

part 'protocol.dart';
part 'region.dart';

class Config {
  RegionProvider regionProvider;
  String token;
  RequestTaskManager manager;
  dynamic region;
  Protocol protocol;

  Config({
    this.regionProvider,
    this.token,
    this.region,
    this.protocol,
    this.manager,
  });
}
