import 'package:flutter/material.dart';

class StringInput extends StatelessWidget {
  final String label;
  final String value;
  final ValueSetter<String> onChanged;
  const StringInput({
    super.key,
    required this.onChanged,
    required this.label,
    this.value = '',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
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
