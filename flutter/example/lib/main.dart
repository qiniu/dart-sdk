import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qiniu_flutter_sdk/qiniu_flutter_sdk.dart';

import 'token.dart';
import 'widgets/progress.dart';
import 'widgets/select_file.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const Home(),
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
    );
  }
}

class Home extends StatelessWidget {
  const Home();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Qiniu SDK Examples',
          textScaleFactor: 0.7,
        ),
      ),
      body: Body(),
    );
  }
}

class Body extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return BodyState();
  }
}

class BodyState extends State<Body> {
  /// storage 实例
  Storage storage;

  /// 当前选择的文件
  File selectedFile;

  dynamic statusValue;

  double progressValue = 1;

  PutController putController;

  @override
  void initState() {
    storage = Storage();
    super.initState();
  }

  void onStatus(dynamic status) {
    setState(() => statusValue = status);
    debugPrint('$statusValue');
  }

  void onProgress(int sent, int total) {
    setState(() => progressValue = sent.toDouble() / total.toDouble());
    debugPrint('$sent, $total, $progressValue');
  }

  void showMessage(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  void onSelectedFile(File file) {
    setState(() {
      selectedFile = file;
      putController = PutController();
    });
    
    putController
      ..addProgressListener(onProgress)
      ..addStatusListener(onStatus);

    storage.putFile(
      file,
      token,
      options: PutOptions(controller: putController),
    )
      .then((dynamic value) {
        showMessage('上传成功');
      })
      .catchError((dynamic error) {
        showMessage(error?.message as String ?? error?.response?.data?.error as String);
      });
  }

  Widget get cancelButton {
    if (statusValue == RequestTaskStatus.Request) {
      return RaisedButton(
        child: Text('取消上传'),
        onPressed: () => putController?.cancel(),
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 40),
        textColor: Colors.white,
        color: Colors.red,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQueryDate = MediaQuery.of(context);

    return Container(
      width: mediaQueryDate.size.width,
      height: mediaQueryDate.size.height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.all(10),
            child: Progress(progressValue),
          ),
          Padding(
            padding: EdgeInsets.all(10),
            child: cancelButton,
          ),
          Padding(
            padding: EdgeInsets.all(10),
            child: SelectFile(onSelectedFile),
          )
        ]..removeWhere((widget) => widget == null),
      ),
    );
  }
}
