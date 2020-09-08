/// ref https://developer.qiniu.com/kodo/manual/1644/security
class Auth {
  final String ak;
  final String sk;
  Auth(this.ak, this.sk);

  String generateManageToken(dynamic params) {
    throw UnimplementedError();
  }

  String generateUploadToken(dynamic params) {
    throw UnimplementedError();
  }

  String generateDownloadToken(dynamic params) {
    throw UnimplementedError();
  }
}
