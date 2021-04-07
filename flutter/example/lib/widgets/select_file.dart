import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

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
  void openSelectFileWindow() async {
    final fileResult = await FilePicker.platform.pickFiles();
    if (fileResult != null && fileResult.paths.first != null) {
      final path = fileResult.paths.first;
      widget.onSelected(File(path!));
    }
  }

  Widget get selectButton {
    return Container(
      width: double.maxFinite,
      child: RaisedButton.icon(
        label: Text('点击选择文件'),
        icon: Icon(Icons.folder),
        onPressed: openSelectFileWindow,
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 40),
        textColor: Colors.white,
        color: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        selectButton,
      ]
    );
  }
}
