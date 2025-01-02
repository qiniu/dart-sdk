import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class SelectFile extends StatefulWidget {
  final ValueSetter<PlatformFile> onSelected;

  const SelectFile(this.onSelected, {super.key});

  @override
  State<StatefulWidget> createState() => SelectFileState();
}

class SelectFileState extends State<SelectFile> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.maxFinite,
          child: ElevatedButton.icon(
            label: const Text('点击选择文件'),
            icon: const Icon(Icons.folder),
            onPressed: () async {
              final fileResult = await FilePicker.platform.pickFiles(
                allowMultiple: false,
              );
              if (fileResult != null) {
                widget.onSelected(fileResult.files.first);
              }
            },
          ),
        ),
      ],
    );
  }
}
