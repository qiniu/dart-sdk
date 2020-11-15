import 'package:flutter/widgets.dart';

abstract class DisposeState<T extends StatefulWidget> extends State<T> {
  List<Function> disposerList = [];

  void addDisposer(Function disposer) {
    disposerList.add(disposer);
  }

  @override
  @mustCallSuper
  void dispose() {
    for (var disposer in disposerList) {
      try {
        disposer?.call();
      } catch (error) {
        // 吞掉错误
      }
    }
    super.dispose();
  }
}
