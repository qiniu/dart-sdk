import 'dart:io';
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1,
    dateTimeFormat: DateTimeFormat.dateAndTime,
  ),
  level: Level.trace,
  filter: ProductionFilter(),
);

void main(List<String> arguments) async {
  final token = "<uptoken>";
  final file = File("<file path>");
  assert(file.existsSync());

  final storage = Storage();
  final controller = PutController();
  controller.addProgressListener((progress) {
    logger.d("Progress: $progress");
  });
  controller.addStatusListener((status) {
    logger.d("Status: $status");
  });
  controller.addSendProgressListener((sendProgress) {
    logger.d("Send Progress: $sendProgress");
  });

  final now = DateTime.now();
  await storage.putFile(
    file,
    token,
    options: PutOptions(
      forceBySingle: true, // 强制表单上传
      controller: controller,
      partSize: 4,
    ),
  );
  logger.d(
    "Upload completed in ${DateTime.now().difference(now).inSeconds} seconds",
  );
}
