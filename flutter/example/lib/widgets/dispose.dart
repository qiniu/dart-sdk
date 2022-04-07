import 'package:flutter/widgets.dart';

abstract class DisposableState<T extends StatefulWidget> extends State<T> {
  List<Function> disposerList = [];

  void addDisposer(Function disposer) {
    disposerList.add(disposer);
  }

  @override
  @mustCallSuper
  void dispose() {
    for (var disposer in disposerList) {
      try {
        disposer.call();
      } catch (error) {
        rethrow;
      }
    }
    super.dispose();
  }
}
