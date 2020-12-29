import 'package:flutter/material.dart';

import 'dispose.dart';

class ConsoleController extends ChangeNotifier {
  List<String> messageList = [];

  void print(String message) {
    messageList.add(message ?? '--');
    notifyListeners();
  }
}

class ConsoleControllerProvider extends InheritedWidget {
  final ConsoleController controller;

  ConsoleControllerProvider({Key key, @required Widget child})
      : controller = ConsoleController(),
        super(key: key, child: child);

  static ConsoleController of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ConsoleControllerProvider>()
        .controller;
  }

  @override
  bool updateShouldNotify(covariant ConsoleControllerProvider oldWidget) {
    return oldWidget.controller != controller;
  }
}

class Console extends StatefulWidget {
  const Console({Key key}) : super(key: key);

  static ConsoleController of(BuildContext context) {
    return ConsoleControllerProvider.of(context);
  }

  @override
  State<StatefulWidget> createState() {
    return ConsoleState();
  }
}

class ConsoleState extends DisposableState<Console> {
  ConsoleController controller;
  List<String> messageList = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    controller = ConsoleControllerProvider.of(context);
    controller?.addListener(onMessageChange);

    addDisposer(() {
      controller?.removeListener(onMessageChange);
    });

    super.didChangeDependencies();
  }

  void onMessageChange() {
    setState(() {
      messageList = controller?.messageList ?? messageList;
    });
  }

  List<Widget> get listChildren {
    final children = <Widget>[];

    if (messageList.isEmpty) {
      return children;
    }

    final reversed = messageList.reversed.toList();
    for (var index = 0; index < reversed.length; index++) {
      children.add(Text('${reversed.length - index}: ${reversed[index]}'));
    }

    return children;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: TextStyle(
        fontSize: 12,
        color: Colors.green[800],
      ),
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        child: LimitedBox(
          maxHeight: 300,
          child: ListView(
            children: listChildren,
          ),
        ),
      ),
    );
  }
}
