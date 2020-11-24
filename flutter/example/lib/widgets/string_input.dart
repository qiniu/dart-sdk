import 'package:flutter/material.dart';

class StringInput extends StatelessWidget {
  final String label;
  final void Function(String token) onChange;
  const StringInput(this.onChange, {Key key, this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: TextField(
        onSubmitted: onChange,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: EdgeInsets.all(20.0),
          border: OutlineInputBorder(
            borderSide: BorderSide(width: 2), // 设置无效，好像有 BUG
            borderRadius: BorderRadius.circular(0.0),
          ),
        ),
      ),
    );
  }
}
