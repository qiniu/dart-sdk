import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

typedef OnSelected = void Function(PlatformFile file);

class SelectFile extends StatefulWidget {
  const SelectFile(this.onSelected, {Key? key}) : super(key: key);

  final OnSelected onSelected;

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
    return SizedBox(
      width: double.maxFinite,
      child: ElevatedButton.icon(
        label: const Text('点击选择文件'),
        icon: const Icon(Icons.folder),
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
