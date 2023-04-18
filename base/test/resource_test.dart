import 'dart:io';

import 'package:path/path.dart';
import 'package:qiniu_sdk_base_diox/src/storage/resource/resource.dart';
import 'package:test/test.dart';

void main() {
  test('bytes resource should work well', () async {
    final filepath = 'test_resource/test_for_put_parts.mp4';
    final bytes = File(filepath).readAsBytesSync();
    final bytesResource = BytesResource(
      bytes: bytes,
      length: bytes.length,
      name: basename(filepath),
      partSize: 1,
    );
    expect(bytesResource.name, basename(filepath));
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
    final filepath = 'test_resource/test_for_put_parts.mp4';
    final file = File(filepath);
    final chunkLengths = <int>[];
    final fileResource = FileResource(
      file: file,
      length: file.lengthSync(),
      partSize: 1,
      name: basename(filepath),
    );
    expect(fileResource.name, basename(filepath));
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
}
