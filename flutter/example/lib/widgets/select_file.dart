import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

typedef OnSelected = void Function(PlatformFile file);

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
    final fileResult =
        await FilePicker.platform.pickFiles(allowMultiple: false);
    if (fileResult != null) {
      widget.onSelected(fileResult.files.first);
    }
  }

  Widget get selectButton {
    return Container(
      width: double.maxFinite,
      child: ElevatedButton.icon(
        label: Text('点击选择文件'),
        icon: Icon(Icons.folder),
        onPressed: openSelectFileWindow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      selectButton,
    ]);
  }
}
