// ignore: import_of_legacy_library_into_null_safe
import 'dart:io';

import 'package:qiniu_sdk_base/src/storage/resource/resource.dart';
import 'package:test/test.dart';

void main() {
  test('bytes resource should work well', () async {
    final bytes =
        File('test_resource/test_for_put_parts.mp4').readAsBytesSync();
    final bytesResource = BytesResource(bytes, bytes.length, partSize: 1);
    final chunkLengths = <int>[];

    await bytesResource.open();

    var n = 0;
    await for (var bytes in bytesResource.stream) {
      n++;
      chunkLengths.add(bytes.length);
      if (n == 1) break;
    }

    // 中断之后接着读应该会继续而不是从头开始
    await for (var bytes in bytesResource.stream) {
      n++;
      chunkLengths.add(bytes.length);
    }

    expect(n, 2);
    expect(chunkLengths[0], 1 * 1024 * 1024);
    expect(chunkLengths[1], bytes.length - 1 * 1024 * 1024);
    await bytesResource.close();
  });

  test('file resource should work well', () async {
    final file = File('test_resource/test_for_put_parts.mp4');
    final chunkLengths = <int>[];
    final fileResource = FileResource(file, file.lengthSync(), partSize: 1);
    await fileResource.open();

    var n = 0;
    await for (var bytes in fileResource.stream) {
      n++;
      chunkLengths.add(bytes.length);
      if (n == 1) break;
    }

    // 中断之后接着读应该会继续而不是从头开始
    await for (var bytes in fileResource.stream) {
      n++;
      chunkLengths.add(bytes.length);
    }

    expect(n, 2);
    expect(chunkLengths[0], 1 * 1024 * 1024);
    expect(chunkLengths[1], file.lengthSync() - 1 * 1024 * 1024);

    await fileResource.close();
  });

  test('stream resource should work well', () async {
    final bytes =
        File('test_resource/test_for_put_parts.mp4').readAsBytesSync();
    final chunkLengths = <int>[];
    final stream = Stream.fromIterable([bytes]);
    final streamResource = StreamResource(stream, bytes.length, partSize: 1);

    await streamResource.open();
    var n = 0;
    await for (var bytes in streamResource.stream) {
      n++;
      chunkLengths.add(bytes.length);
      if (n == 1) break;
    }

    // 中断之后接着读应该会继续而不是从头开始
    await for (var bytes in streamResource.stream) {
      n++;
      chunkLengths.add(bytes.length);
    }

    expect(n, 2);
    expect(chunkLengths[0], 1 * 1024 * 1024);
    expect(chunkLengths[1], bytes.length - 1 * 1024 * 1024);

    await streamResource.close();
  });
}
