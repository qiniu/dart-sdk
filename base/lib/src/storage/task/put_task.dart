import 'dart:io';

import 'package:meta/meta.dart';

import 'put_by_single_task.dart';
import 'put_parts_task/put_parts_task.dart';
import 'put_response.dart';
import 'request_task.dart';

class PutTask extends RequestTask<PutResponse> {
  final File file;
  final String token;

  final int automaticSliceSize;

  final int partSize;
  final int maxPartsRequestNumber;

  final String key;

  PutTask({
    @required this.file,
    @required this.token,
    this.automaticSliceSize,
    this.partSize,
    this.maxPartsRequestNumber,
    this.key,
  });

  bool usePart(int fileSize) {
    return fileSize > (automaticSliceSize * 1024 * 1024);
  }

  @override
  Future<PutResponse> createTask() {
    final fileSize = file.lengthSync();
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

    return (manager.addTask(task) as RequestTask<PutResponse>).future;
  }
}
