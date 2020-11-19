import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qiniu_flutter_sdk/qiniu_flutter_sdk.dart';
import 'package:qiniu_flutter_sdk_example/widgets/console.dart';

import 'token.dart';
import 'utils/uint.dart';
import 'widgets/app.dart';
import 'widgets/dispose.dart';
import 'widgets/progress.dart';
import 'widgets/select_file.dart';
import 'widgets/token_input.dart';

void main() {
  runApp(
    App(
      child: Base(),
    ),
  );
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
  String token;

  /// storage 实例
  Storage storage;

  /// 当前选择的文件
  File selectedFile;

  // 当前的进度
  double progressValue = 1;

  // 当前的任务状态
  RequestTaskStatus statusValue;

  // 控制器，可以用于取消任务、获取上述的状态，进度等信息
  PutController putController;

  @override
  void initState() {
    storage = Storage();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void onStatus(RequestTaskStatus status) {
    printToConsole('状态变化: 当前任务状态：${status.toString()}');
    setState(() => statusValue = status);
  }

  void onProgress(int sent, int total) {
    final progress = sent.toDouble() / total.toDouble();
    final sentStr = humanizeFileSize(sent.toDouble());
    setState(() => progressValue = progress);

    printToConsole('进度变化：进度：${progress.toStringAsFixed(2)}, 已发送：$sentStr');
  }

  void printToConsole(String message) {
    if (message == null || message == '') {
      return;
    }

    debugPrint(message);
    Console.of(context).print(message);
  }

  void startUpload() {
    printToConsole('创建 PutController');
    putController = PutController();

    printToConsole('添加进度订阅');
    addDisposer(putController.addProgressListener(onProgress));

    printToConsole('添加状态订阅');
    addDisposer(putController.addStatusListener(onStatus));

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

    try {
      printToConsole('开始上传文件');
      storage.putFile(
        selectedFile,
        usedToken,
        options: PutOptions(
          controller: putController,
          partSize: 1,
        ),
      )
        ..then((PutResponse response) {
          printToConsole('上传已完成: 原始响应数据: ${jsonEncode(response.rawData)}');
          printToConsole('------------------------');
        })
        ..catchError((dynamic error) {
          var message = '未知错误';

          if (error.error != null) {
            message = error.error as String;
          }

          if (error.message != null) {
            message = error.message as String;
          }

          if (error.response != null &&
              error.response.data != null &&
              error.response.data['error'] != null) {
            message = error.response.data['error'] as String;
          }

          printToConsole('发生错误: $message');
          printToConsole('------------------------');
        });
    } catch (error) {
      printToConsole('发生 SDK 级别未知错误，请联系开发者: ${error.toString()}');
    }
  }

  void onSelectedFile(File file) {
    printToConsole('选中文件: ${file.path}');
    printToConsole('文件尺寸：${humanizeFileSize(file.lengthSync().toDouble())}');

    setState(() {
      printToConsole('设置 selectedFile');
      selectedFile = file;

      startUpload();
    });
  }

  void onChangedToken(String token) {
    printToConsole('设置 Token: $token');
    this.token = token;
  }

  Widget get cancelButton {
    if (statusValue == RequestTaskStatus.Request) {
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
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.all(20),
          child: Progress(progressValue),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TokenInput(onChangedToken),
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
      ]..removeWhere((widget) => widget == null),
    );
  }
}
