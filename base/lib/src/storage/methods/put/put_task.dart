import 'dart:io';

import 'package:meta/meta.dart';

import '../../config/config.dart';
import '../../task/request_task.dart';
import '../../task/task.dart';
import 'by_part/put_parts_task.dart';
import 'by_single/put_by_single_task.dart';
import 'put_response.dart';

class PutTask extends Task<PutResponse> {
  final File file;
  final String token;

  final bool forceBySingle;

  final int partSize;
  final int maxPartsRequestNumber;

  final String key;
  final RequestTaskController controller;
  final HostProvider hostProvider;

  PutTask({
    @required this.file,
    @required this.token,
    @required this.hostProvider,
    this.forceBySingle,
    this.partSize,
    this.maxPartsRequestNumber,
    this.key,
    this.controller,
  })  : assert(file != null),
        assert(token != null);

  bool usePart(int fileSize) {
    return forceBySingle == false && fileSize > (partSize * 1024 * 1024);
  }

  @override
  Future<PutResponse> createTask() async {
    Task<PutResponse> task;
    final fileSize = await file.length();

    /// 文件尺寸大于设置的数值时使用分片上传
    if (usePart(fileSize)) {
      task = PutByPartTask(
        file: file,
        token: token,
        key: key,
        maxPartsRequestNumber: maxPartsRequestNumber,
        partSize: partSize,
        controller: controller,
        hostProvider: hostProvider,
      );
      manager.addTask(task);
    } else {
      task = PutBySingleTask(
        file: file,
        token: token,
        key: key,
        controller: controller,
      );
      manager.addRequestTask(task as RequestTask<PutResponse>);
    }

    return task.future;
  }
}
