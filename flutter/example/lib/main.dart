import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qiniu_flutter_sdk/qiniu_flutter_sdk.dart';

import 'token.dart';
import 'utils/uint.dart';
import 'widgets/app.dart';
import 'widgets/console.dart';
import 'widgets/dispose.dart';
import 'widgets/progress.dart';
import 'widgets/select_file.dart';
import 'widgets/string_input.dart';

void main() {
  runApp(App(child: Base()));
}

// 基础的上传示例
class Base extends StatefulWidget implements Example {
  @override
  String get title => '基础上传示例';

  @override
  State<Base> createState() {
    return BaseState();
  }
}

class BaseState extends DisposableState<Base> {
  BaseState() : storage = Storage();

  // 用户输入的文件名
  String? key;

  // 用户输入的 partSize
  int partSize = 4;

  // 用户输入的 token
  String? token;

  /// storage 实例
  final Storage storage;

  /// 当前选择的文件
  Uint8List? selectedFile;

  // 当前的进度
  double progressValue = 1;

  // 当前的任务状态
  StorageStatus? statusValue;

  // 控制器，可以用于取消任务、获取上述的状态，进度等信息
  PutController? putController;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void onStatus(StorageStatus status) {
    printToConsole('状态变化: 当前任务状态：${status.toString()}');
    setState(() => statusValue = status);
  }

  void onProgress(double percent) {
    setState(() => progressValue = percent);
    printToConsole('任务进度变化：进度：${percent.toStringAsFixed(4)}');
  }

  void onSendProgress(double percent) {
    // setState(() => progressValue = percent);
    printToConsole('实际发送变化：进度：${percent.toStringAsFixed(4)}');
  }

  void printToConsole(String? message) {
    if (message == null || message == '') {
      return;
    }

    debugPrint(message);
    Console.of(context).print(message);
  }

  void startUpload() {
    printToConsole('创建 PutController');
    putController = PutController();

    printToConsole('添加实际发送进度订阅');
    addDisposer(putController!.addSendProgressListener(onSendProgress));

    printToConsole('添加任务进度订阅');
    addDisposer(putController!.addProgressListener(onProgress));

    printToConsole('添加状态订阅');
    addDisposer(putController!.addStatusListener(onStatus));

    var usedToken = token;

    if (token == null || token == '') {
      if (builtinToken != null && builtinToken != '') {
        printToConsole('使用内建 Token 进行上传');
        usedToken = builtinToken;
      }
    }

    if (usedToken == null || usedToken == '') {
      printToConsole('token 不能为空');
      return;
    }

    if (selectedFile == null) {
      printToConsole('请选择文件');
      return;
    }
    print(selectedFile);
    printToConsole('开始上传文件');
    storage.putBytes(
      selectedFile!,
      usedToken,
      options: PutBySingleOptions(
        key: key,
        // partSize: partSize,
        controller: putController,
      ),
    )
      ..then((PutResponse response) {
        printToConsole('上传已完成: 原始响应数据: ${jsonEncode(response.rawData)}');
        printToConsole('------------------------');
      })
      ..catchError((dynamic error) {
        if (error is StorageError) {
          switch (error.type) {
            case StorageErrorType.CONNECT_TIMEOUT:
              printToConsole('发生错误: 连接超时');
              break;
            case StorageErrorType.SEND_TIMEOUT:
              printToConsole('发生错误: 发送数据超时');
              break;
            case StorageErrorType.RECEIVE_TIMEOUT:
              printToConsole('发生错误: 响应数据超时');
              break;
            case StorageErrorType.RESPONSE:
              printToConsole('发生错误: ${error.message}');
              break;
            case StorageErrorType.CANCEL:
              printToConsole('发生错误: 请求取消');
              break;
            case StorageErrorType.UNKNOWN:
              printToConsole('发生错误: 未知错误');
              break;
            case StorageErrorType.NO_AVAILABLE_HOST:
              printToConsole('发生错误: 无可用 Host');
              break;
            case StorageErrorType.IN_PROGRESS:
              printToConsole('发生错误: 已在队列中');
              break;
          }
        } else {
          printToConsole('发生错误: ${error.toString()}');
        }

        printToConsole('------------------------');
      });
  }

  void onSelectedFile(Uint8List file) {
    // printToConsole('选中文件: ${file.path}');
    // printToConsole('文件尺寸：${humanizeFileSize(file.lengthSync().toDouble())}');

    setState(() {
      printToConsole('设置 selectedFile');
      selectedFile = file;

      startUpload();
    });
  }

  void onPartSizeChange(String partSize) {
    if (partSize == '') {
      printToConsole('设置默认 partSize');
      this.partSize = 4;
      return;
    }

    printToConsole('设置 partSize: $partSize');
    this.partSize = int.parse(partSize);
  }

  void onTokenChange(String token) {
    if (token == '') {
      printToConsole('清除 token');
      this.token = null;
      return;
    }

    printToConsole('设置 Token: $token');
    this.token = token;
  }

  void onKeyChange(String key) {
    if (key == '') {
      printToConsole('清除 key');
      this.key = null;
      return;
    }

    printToConsole('设置 key: $key');
    this.key = key;
  }

  Widget get cancelButton {
    if (statusValue == StorageStatus.Request) {
      return Padding(
        padding: EdgeInsets.all(10),
        child: RaisedButton(
          child: Text('取消上传'),
          onPressed: () => putController?.cancel(),
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 40),
          textColor: Colors.white,
          color: Colors.red,
        ),
      );
    }
    return SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Padding(
        padding: EdgeInsets.all(20),
        child: Progress(progressValue),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: StringInput(
          onKeyChange,
          label: '请输入 Key（可选）',
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: StringInput(
          onPartSizeChange,
          label: '请输入分片尺寸，单位 M（默认 4，可选）',
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: StringInput(
          onTokenChange,
          label: '请输入 Token（可选）',
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: SelectFile(onSelectedFile),
      ),
      // 取消按钮
      cancelButton,
      Padding(
        key: Key('console'),
        child: const Console(),
        padding: EdgeInsets.all(8.0),
      ),
    ]);
  }
}
