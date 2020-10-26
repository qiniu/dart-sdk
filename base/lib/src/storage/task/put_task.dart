import 'dart:io';

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

  final String? key;

  PutTask({
    required this.file,
    required this.token,
    this.automaticSliceSize = 4,
    this.partSize = 4,
    this.maxPartsRequestNumber = 5,
    this.key,
  });

  @override
  Future<PutResponse> createTask() {
    final fileSize = file.lengthSync();
    late final RequestTask<PutResponse> task;

    /// 文件尺寸大于设置的数值时使用分片上传
    if (fileSize > (automaticSliceSize * 1024 * 1024)) {
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
