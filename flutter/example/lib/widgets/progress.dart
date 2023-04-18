import 'package:flutter/material.dart';

class Progress extends StatelessWidget {
  const Progress(this.value, {Key? key}) : super(key: key);

  final double value;

  Widget get progress {
    return Container(
      width: 200,
      height: 200,
      padding: const EdgeInsets.all(20),
      child: CircularProgressIndicator(
        value: value,
        strokeWidth: 14,
        backgroundColor: Colors.grey[200],
      ),
    );
  }

  Widget get progressText {
    final integer = (value * 100).toInt();
    final decimal = (((value * 100) - integer) * 100).toInt();
    const unit = '%';

    return DefaultTextStyle(
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              integer.toString(),
              style: const TextStyle(fontSize: 50),
            ),
            Column(
              children: [
                Text(unit.toString(), style: const TextStyle(fontSize: 14)),
                Text('.$decimal', style: const TextStyle(fontSize: 18)),
              ],
            )
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [progress, progressText],
    );
  }
}
