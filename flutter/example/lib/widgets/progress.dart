import 'package:flutter/material.dart';

class Progress extends StatelessWidget {
  final double value;
  Progress(this.value);

  Widget get progress {
    return Container(
      width: 160,
      height: 160,
      padding: EdgeInsets.all(20),
      child: CircularProgressIndicator(
        value: value,
        strokeWidth: 16,
        backgroundColor: Colors.blue[50],
      ),
    );
  }

  Widget get progressText {
    return Text(
      '${(value * 100).toStringAsFixed(2)}%',
      style: TextStyle(fontSize: 18),
      textAlign: TextAlign.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [progress, progressText],
    );
  }
}
