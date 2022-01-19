// ignore: import_of_legacy_library_into_null_safe
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:qiniu_sdk_base/src/storage/resource/resource.dart';
import 'package:test/test.dart';

void main() {
  test('bytes resource should work well', () async {
    final bytes =
        File('test_resource/test_for_put_parts.mp4').readAsBytesSync();
    final bytesResource =
        BytesResource(bytes: bytes, length: bytes.length, partSize: 1);
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
    final fileResource =
        FileResource(file: file, length: file.lengthSync(), partSize: 1);
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
    final streamResource = StreamResource(
        stream: stream, length: bytes.length, id: 'test', partSize: 1);

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

  test('random emit chunk should work well', () async {
    final bytes =
        File('test_resource/test_for_put_parts.mp4').readAsBytesSync();
    final chunkLengths = <int>[];
    // 把 bytes 随机切割成 n 份 chunk
    final chunks = splitBytesToChunks(bytes);
    final stream = Stream.fromIterable(chunks);
    final streamResource = StreamResource(
        stream: stream, length: bytes.length, id: 'test', partSize: 1);
    await streamResource.open();
    var n = 0;
    await for (var bytes in streamResource.stream) {
      n++;
      print(bytes.length);
      chunkLengths.add(bytes.length);
    }
    // 不管 rawStream 是如何 emit chunk 给 StreamResource 的，StreamResource 都是按照 partSize 往外 emit
    // 所以这里应该还是 2 片
    expect(n, 2);
    expect(chunkLengths[0], 1 * 1024 * 1024);
    expect(chunkLengths[1], bytes.length - 1 * 1024 * 1024);
    await streamResource.close();
  });
}

List<List<int>> splitBytesToChunks(Uint8List bytes) {
  final _random = Random();
  int _randomBetween(int min, int max) {
    if (max - min <= 0) return min;
    return min + _random.nextInt(max - min);
  }

  var start = 0;
  var end = _randomBetween(start + 1, bytes.length);
  final chunks = <List<int>>[];
  while (end <= bytes.length) {
    final chunk = bytes.sublist(start, end);
    chunks.add(chunk);
    start = end;
    end = _randomBetween(start + 1, bytes.length);
  }
  return chunks;
}
