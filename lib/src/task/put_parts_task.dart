import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:qiniu_sdk_base/src/auth/auth.dart';
import 'task.dart';

/// initParts 的返回体
class InitParts {
  String uploadId;
  int expireAt;

  InitParts({this.uploadId, this.expireAt});

  factory InitParts.fromJson(Map json) {
    return InitParts(uploadId: json['uploadId'], expireAt: json['expireAt']);
  }
}

class InitPartsTask<T extends InitParts> extends AbstractRequestTask<T> {
  String token;
  String bucket;
  String host;
  String key;

  InitPartsTask({
    this.host,
    this.bucket,
    this.token,
    this.key,
  });

  @override
  Future<T> createTask() async {
    final response = await client.post(
        '$host/buckets/$bucket/objects/${base64Url.encode(utf8.encode(key))}/uploads',
        data: {},
        options: Options(
            headers: {'Content-Length': 0, 'Authorization': 'UpToken $token'}));

    return InitParts.fromJson(response.data);
  }
}

/// uploadPart 的返回体
class UploadPart {
  String etag;
  String md5;

  UploadPart({this.etag, this.md5});

  factory UploadPart.fromJson(Map json) {
    return UploadPart(etag: json['etag'], md5: json['md5']);
  }
}

class UploadPartTask<T extends UploadPart> extends AbstractRequestTask<T> {
  String token;
  String host;
  String bucket;
  String key;
  String uploadId;
  int partNumber;
  Stream<List<int>> byteStream;

  UploadPartTask({
    this.token,
    this.host,
    this.bucket,
    this.key,
    this.uploadId,
    this.byteStream,
    this.partNumber,
  });

  @override
  Future<T> createTask() async {
    final response = await client.put(
        '$host/buckets/$bucket/objects/${base64Url.encode(utf8.encode(key))}/uploads/$uploadId/$partNumber',
        data: byteStream,
        options: Options(headers: {'Authorization': 'UpToken $token'}));

    return UploadPart.fromJson(response.data);
  }
}

/// completeParts 需要的区块信息
class Part {
  String etag;
  int partNumber;

  Part({this.etag, this.partNumber});

  factory Part.fromJson(Map json) {
    return Part(etag: json['map'], partNumber: json['partNumber']);
  }

  Map toJson() {
    return {'etag': etag, 'partNumber': partNumber};
  }
}

/// completeParts 的返回体
class CompleteParts {
  /// 资源内容的 SHA1 值
  String hash;

  /// 上传到七牛云存储后资源名称
  String key;

  CompleteParts({this.hash, this.key});

  factory CompleteParts.fromJson(Map json) {
    return CompleteParts(hash: json['hash'], key: json['key']);
  }
}

class CompletePartsTask<T extends CompleteParts>
    extends AbstractRequestTask<T> {
  String token;
  String host;
  String bucket;
  String key;
  String uploadId;
  List<Part> parts;

  CompletePartsTask({
    this.token,
    this.host,
    this.bucket,
    this.key,
    this.uploadId,
    this.parts,
  });

  @override
  Future<T> createTask() async {
    final response = await client.post(
        '$host/buckets/$bucket/objects/${base64Url.encode(utf8.encode(key))}/uploads/$uploadId',
        data: {
          'parts': parts
            ..sort((a, b) => a.partNumber - b.partNumber)
            ..map((part) => part.toJson()).toList()
        },
        options: Options(headers: {'Authorization': 'UpToken $token'}));

    return CompleteParts.fromJson(response.data);
  }
}

class UploadPartsTask<T extends List<Part>> extends AbstractRequestTask<T> {
  String token;
  String host;
  String uploadId;
  File file;
  String bucket;
  String key;
  int chunkSize;
  int maxPartsRequestNumber;

  final List<Part> _parts = [];
  int _byteStartOffset = 0;
  int _partNumber = 0;
  final List<AbstractRequestTask> _currentWorkingTasks = [];

  final List<UploadPartTask> _canceledTasks = [];

  UploadPartsTask({
    this.token,
    this.host,
    this.chunkSize,
    this.uploadId,
    this.file,
    this.bucket,
    this.key,
    this.maxPartsRequestNumber,
  });

  @override
  Future<T> createTask() async {
    await _uploadParts();

    return _parts;
  }

  Future _uploadParts() async {
    /// 取消过的任务重新加入队列
    var _idleRequestNumber = maxPartsRequestNumber;
    if (_canceledTasks.length <= _idleRequestNumber) {
      _idleRequestNumber -= _canceledTasks.length;
      for (final task in _canceledTasks) {
        task.resume();
      }
    }

    final _fileLength = await file.length();
    final _chunkLength = chunkSize * 1024 * 1024;

    do {
      final byteEndOffset = _byteStartOffset + _chunkLength;
      final byteStream = file.openRead(_byteStartOffset, byteEndOffset);

      _byteStartOffset += _chunkLength;

      final __partNumber = ++_partNumber;

      _idleRequestNumber--;

      final task = UploadPartTask(
        token: token,
        host: host,
        bucket: bucket,
        key: key,
        byteStream: byteStream,
        uploadId: uploadId,
        partNumber: __partNumber,
      );

      task.onReceive = (data) {
        _currentWorkingTasks.remove(task);
        _canceledTasks.remove(task);
        _parts.add(Part(partNumber: __partNumber, etag: data.etag));
      };

      task.onCancel = (error) {
        _canceledTasks.add(task);
      };

      task.onError = (error) {
        postError(error);
      };

      manager.addRequestTask(task);

      _currentWorkingTasks.add(task);
    } while (_idleRequestNumber > 0 && _byteStartOffset < _fileLength);

    final futures = _currentWorkingTasks.map((task) => task.toFuture());

    try {
      /// 任务有可能被取消，取消会导致报错
      await Future.wait(futures);
    } catch (e) {
      postError(e);
      return;
    }

    if (_byteStartOffset < _fileLength) {
      await _uploadParts();
    }
  }
}

/// 上传块任务
class PutPartsTask extends AbstractRequestTask<CompleteParts> {
  File file;
  String key;
  String token;
  String bucket;
  int chunkSize;
  dynamic region;
  int maxPartsRequestNumber;
  Protocol protocol;

  PutPartsTask({
    this.key,
    this.file,
    this.token,
    this.chunkSize,
    this.region,
    this.maxPartsRequestNumber,
    this.protocol,
  });

  String uploadId;
  AbstractRequestTask _currentWorkingTask;

  @override
  void preStart() {
    super.preStart();
    bucket = Auth.parseToken(token).putPolicy.getBucket();
  }

  @override
  void postReceive(CompleteParts data) {
    _currentWorkingTask = null;
    super.postReceive(data);
  }

  @override
  void cancel() {
    _currentWorkingTask?.cancel();
    super.cancel();
  }

  @override
  Future<CompleteParts> createTask() async {
    final com = Completer<CompleteParts>();

    final host = region != null
        ? config.regionProvider.getHostByRegion(region)
        : await config.regionProvider.getHostByToken(token);

    _createInitParts(
      (CompleteParts data) => com.complete(data),
      (error) => com.completeError(error),
      host,
    );

    return com.future;
  }

  /// 初始化上传信息，分片上传的第一步
  void _createInitParts(void Function(CompleteParts) done,
      void Function(dynamic) error, String host) {
    InitPartsTask task;
    if (_currentWorkingTask is InitPartsTask) {
      task = _currentWorkingTask;
      task.resume();
    } else {
      task = InitPartsTask(
        token: token,
        host: host,
        bucket: bucket,
        key: key,
      );
      _currentWorkingTask = manager.addRequestTask(task);
    }

    task.onReceive = (data) {
      uploadId = data.uploadId;

      _createUploadParts(done, error, host);
    };

    task.onCancel = error;

    task.onError = error;
  }

  void _createUploadParts(void Function(CompleteParts) done,
      void Function(dynamic) error, String host) {
    UploadPartsTask task;
    if (_currentWorkingTask is UploadPartsTask) {
      task = _currentWorkingTask;
      task.resume();
    } else {
      task = UploadPartsTask(
        token: token,
        host: host,
        bucket: bucket,
        key: key,
        file: file,
        chunkSize: chunkSize,
        uploadId: uploadId,
        maxPartsRequestNumber: maxPartsRequestNumber,
      );
      _currentWorkingTask = manager.addRequestTask(task);
    }

    task.onReceive = (data) {
      _createCompleteParts(done, error, data, host);
    };

    task.onCancel = error;

    task.onError = error;
  }

  /// 创建文件，分片上传的最后一步
  void _createCompleteParts(
    void Function(CompleteParts) done,
    void Function(dynamic) error,
    List<Part> parts,
    String host,
  ) async {
    CompletePartsTask task;
    if (_currentWorkingTask is CompletePartsTask) {
      task = _currentWorkingTask;
      task.resume();
    } else {
      task = CompletePartsTask(
        token: token,
        host: host,
        bucket: bucket,
        key: key,
        uploadId: uploadId,
        parts: parts,
      );
      _currentWorkingTask = manager.addRequestTask(task);
    }
    task.onReceive = (response) {
      done(response);
    };

    task.onCancel = error;

    task.onError = (e) {
      error(e);
    };
  }
}
