import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

typedef OnSelected = void Function(File file);

class SelectFile extends StatefulWidget {
  final OnSelected onSelected;
  const SelectFile(this.onSelected);

  @override
  State<StatefulWidget> createState() {
    return SelectFileState();
  }
}

class SelectFileState extends State<SelectFile> {
  String selectedFilePath;

  void openSelectFileWindow() async {
    final fileResult = await FilePicker.platform.pickFiles();
    if (fileResult != null && fileResult.paths?.first != null) {
      setState(() => selectedFilePath = fileResult.paths?.first);
      widget.onSelected(File(fileResult.paths?.first));
    }
  }

  Widget get selectButton {
    return RaisedButton(
      child: Text('选择文件'),
      onPressed: openSelectFileWindow,
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 40),
      textColor: Colors.white,
      color: Colors.blue,
    );
  }

  Widget get selectedFileName {
    if (selectedFilePath == null) {
      return null;
    }
    return Container(
      color: Colors.grey[200],
      padding: EdgeInsets.all(10),
      child: Text( basename(selectedFilePath)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          selectedFileName,
          selectButton,
        ]..removeWhere((widget) => widget == null),
      ),
    );
  }
}
