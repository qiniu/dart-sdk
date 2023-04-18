import 'package:flutter/material.dart';

class StringInput extends StatelessWidget {
  final String label;
  final String value;
  final void Function(String token) onChange;
  const StringInput(this.onChange,
      {Key? key, required this.label, this.value = ''})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      onSubmitted: onChange,
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.all(20.0),
        border: OutlineInputBorder(
          borderSide: const BorderSide(width: 2), // 设置无效，好像有 BUG
          borderRadius: BorderRadius.circular(0.0),
        ),
      ),
    );
  }
}
