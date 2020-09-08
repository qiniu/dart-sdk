import '../network/network.dart';
import 'controller.dart';
import 'upload.dart';

class Storage {
  Upload uploadModule;

  Storage({NetWork netWork}) {
    uploadModule = Upload(netWork: netWork);
  }

  Controller upload() {
    throw UnimplementedError();
  }
}
