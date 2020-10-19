import 'package:flutter/material.dart';

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

class Drawer extends StatelessWidget {
  const Drawer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: Icon(Icons.file_upload),
          title: Text('文件上传'),
        ),
        ListTile(
          leading: Icon(Icons.file_upload),
          title: Text('拍照上传'),
        ),
        ListTile(
          leading: Icon(Icons.file_upload),
          title: Text('文本上传'),
        )
      ],
    );
  }
}

class Home extends StatelessWidget {
  const Home();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const Drawer(),
      appBar: new AppBar(title: new Text('Qiniu SDK Examples')),
    );
  }
}
