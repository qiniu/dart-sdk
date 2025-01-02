import 'package:flutter/widgets.dart';

mixin DisposableState<T extends StatefulWidget> on State<T> {
  List<VoidCallback> disposerList = [];

  void addDisposer(VoidCallback disposer) {
    disposerList.add(disposer);
  }

  @override
  @mustCallSuper
  void dispose() {
    for (final disposer in disposerList) {
      try {
        disposer();
      } catch (error) {
        rethrow;
      }
    }
    super.dispose();
  }
}
