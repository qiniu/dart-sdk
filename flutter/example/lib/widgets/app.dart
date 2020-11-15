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

// class AppBar extends StatelessWidget implements PreferredSizeWidget {
//   final String title;

//   const AppBar({Key key, this.title}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     // MediaQuery.of(context).padding.top

//     return Padding(
//       padding: EdgeInsets.symmetric(
//         horizontal: 20,
//         vertical: 30,
//       ),
//       child: Text(
//         title,
//         style: TextStyle(
//           fontSize: 20,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }

//   @override
//   Size get preferredSize => Size.fromHeight(80);
// }
