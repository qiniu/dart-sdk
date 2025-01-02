import 'package:flutter/material.dart';

import 'console.dart';

abstract class Example implements Widget {
  String get title;
}

class App extends StatelessWidget {
  final Example child;

  const App({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ConsoleControllerProvider(
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: Text(
              child.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
