import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiniu_flutter_sdk_example/main.dart' as example;

void main() {
  testWidgets('renders the upload example shell', (tester) async {
    example.main();
    await tester.pump();

    expect(find.text('基础上传示例'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();

    expect(find.text('点击选择文件'), findsOneWidget);
    expect(find.byIcon(Icons.folder), findsOneWidget);
  });
}
