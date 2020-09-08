import '../network/network.dart';
import 'controller.dart';

typedef GetToken = String Function(dynamic params);

class Upload {
  NetWork netWork;

  Upload({
    String token,
    GetToken getToken,
    NetWork netWork,
  }) : assert(token != null || getToken == null);

  Controller upload() {
    throw UnimplementedError();
  }
}
