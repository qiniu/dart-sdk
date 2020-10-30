import 'dart:io';

import 'package:meta/meta.dart';

import '../../task/request_task.dart';
import 'by_part/put_parts_task.dart';
import 'by_single/put_by_single_task.dart';
import 'put_response.dart';

class PutTask extends RequestTask<PutResponse> {
  final File file;
  final String token;

  final bool forceBySingle;

  final int partSize;
  final int maxPartsRequestNumber;

  final String key;

  PutTask({
    @required this.file,
    @required this.token,
    this.forceBySingle,
    this.partSize,
    this.maxPartsRequestNumber,
    this.key,
  });

  bool usePart(int fileSize) {
    return forceBySingle == false && fileSize > (partSize * 1024 * 1024);
  }

  @override
  Future<PutResponse> createTask() async {
    final fileSize = await file.length();
    RequestTask<PutResponse> task;

    /// 文件尺寸大于设置的数值时使用分片上传
    if (usePart(fileSize)) {
      task = PutByPartTask(
        file: file,
        token: token,
        key: key,
        maxPartsRequestNumber: maxPartsRequestNumber,
        partSize: partSize,
      );
    } else {
      task = PutBySingleTask(
        file: file,
        token: token,
        key: key,
      );
    }

    task.addProgressListener(notifyProgressListeners);

    manager.addTask(task);
    return task.future;
  }
}
