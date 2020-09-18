import 'package:dio/dio.dart';

import '../utils.dart';

typedef ProgressListener = void Function(int sent, int total);

mixin ProgressListenersMixin {
  final List<ProgressListener> _progressListeners = [];

  void listenProgress(ProgressListener listener);

  void unlistenProgress(ProgressListener listener);

  void notifyProgressListeners(int sent, int total);
}

abstract class AbstractRequestTask with ProgressListenersMixin {
  dynamic _request;

  set request(dynamic request) {
    _request = request;
  }

  Future toFuture();

  void preStart() {}

  void run();

  void postStop() {}
}

class SingleTask<T> extends AbstractRequestTask with ListenersMixin {
  CancelToken _cancelToken;
  void Function(int sent, int total) progressReceiver;
  final Dio http = Dio();

  SingleTask({CancelToken cancelToken}) : _cancelToken = cancelToken;

  factory SingleTask.create(
      dynamic Function(CancelToken cancelToken,
              void Function(int sent, int total) progressReceiver)
          runnable) {
    final cancelToken = CancelToken();
    final task = SingleTask(cancelToken: cancelToken);
    final progressReceiver = (int sent, int total) {
      task.notifyProgressListeners(sent, total);
    };
    final request = runnable(cancelToken, progressReceiver).catchError((e) {
      print(e);
    });
    task.request = request;

    return task;
  }

  @override
  Future<T> toFuture() {
    return _request;
  }

  void cancel() {
    _cancelToken.cancel();
  }

  @override
  void listenProgress(ProgressListener listener) {
    _progressListeners.add(listener);
  }

  @override
  void unlistenProgress(ProgressListener listener) {
    _progressListeners.remove(listener);
  }

  @override
  void notifyProgressListeners(int sent, int total) {
    for (final listener in _progressListeners) {
      listener(sent, total);
    }
  }

  @override
  void listen(listener) {
    // TODO: implement listen
  }

  @override
  void notifyListeners() {
    // TODO: implement notifyListeners
  }

  @override
  void unlisten(listener) {
    // TODO: implement unlisten
  }

  @override
  void run() {
    
  }
}
