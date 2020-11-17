import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'console.dart';

abstract class Example implements Widget {
  String get title;
}

class App extends StatelessWidget {
  final Example child;

  const App({Key key, this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ConsoleControllerProvider(
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
            ),
            child: child,
          ),
          appBar: AppBar(
            title: Text(
              child.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
