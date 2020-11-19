import 'package:flutter/material.dart';

class TokenInput extends StatelessWidget {
  final void Function(String token) onChange;

  const TokenInput(this.onChange, {Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: TextField(
        onSubmitted: onChange,
        decoration: InputDecoration(
          labelText: '请输入 Token',
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
