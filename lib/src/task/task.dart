import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../config.dart';
import '../utils.dart';

typedef ProgressListener = void Function(int sent, int total);

mixin ProgressListenersMixin {
  final List<ProgressListener> progressListeners = [];

  void listenProgress(ProgressListener listener);

  void unlistenProgress(ProgressListener listener);

  void notifyProgressListeners(int sent, int total);
}

typedef TaskListener<T> = void Function(void Function(T data) onData,
    {Function onError, void Function() onDone, bool cancelOnError});

mixin TaskListenersMixin {
  List<TaskListener> taskListener = [];

  void listenTask(TaskListener listener);

  void unlistenTask(TaskListener listener);

  void notifyTaskListeners(dynamic value);
}

class RequestTaskConfig {
  RegionProvider regionProvider;
  String token;
  Protocol upprotocol;

  RequestTaskConfig({this.regionProvider, this.token, this.upprotocol});
}

typedef ReceiveListener<T> = void Function(Response<T>)

abstract class AbstractRequestTask<T> with ProgressListenersMixin {
  final Dio client = Dio();
  final cancelToken = CancelToken();

  /// TaskManager 那边实现
  RequestTaskConfig config;

  Future request;

  final List<ReceiveListener<T>> _reseiveListeners = [];
  void Function(ReceiveListener<T>) onReceive(ReceiveListener<T> listener) {
    _reseiveListeners.add(listener);
  }

  void Function(DioError) onError;

  void Function() onDone;

  void Function() onCancel;

  Future createRequest();

  void cancel() {
    cancelToken.cancel();
  }

  @mustCallSuper
  void preStart() {
    client.interceptors.add(InterceptorsWrapper(onError: (error) {
      postError(error);
    }, onResponse: (response) {
      postReceive(response);
      postComplete();
    }));
  }

  @mustCallSuper
  void postReceive(Response<T> data) {
    for (final listener in _reseiveListeners) {
      listener(data);
    }
  }

  @mustCallSuper
  void postComplete() {
    onDone?.call();
  }

  @mustCallSuper
  void postCancel() {
    /// TODO
    onCancel?.call();
  }

  @mustCallSuper
  void postError(DioError error) {
    onError?.call(error);
  }
}

// class SingleTask<T> extends AbstractRequestTask with ListenersMixin {
//   CancelToken _cancelToken;
//   void Function(int sent, int total) progressReceiver;
//   final Dio http = Dio();

//   SingleTask({CancelToken cancelToken}) : _cancelToken = cancelToken;

//   factory SingleTask.create(
//       dynamic Function(CancelToken cancelToken,
//               void Function(int sent, int total) progressReceiver)
//           runnable) {
//     final cancelToken = CancelToken();
//     final task = SingleTask(cancelToken: cancelToken);
//     final progressReceiver = (int sent, int total) {
//       task.notifyProgressListeners(sent, total);
//     };
//     final request = runnable(cancelToken, progressReceiver).catchError((e) {
//       print(e);
//     });
//     task.request = request;

//     return task;
//   }

//   @override
//   Future<T> toFuture() {
//     return _request;
//   }

//   void cancel() {
//     _cancelToken.cancel();
//   }

//   @override
//   void listenProgress(ProgressListener listener) {
//     _progressListeners.add(listener);
//   }

//   @override
//   void unlistenProgress(ProgressListener listener) {
//     _progressListeners.remove(listener);
//   }

//   @override
//   void notifyProgressListeners(int sent, int total) {
//     for (final listener in _progressListeners) {
//       listener(sent, total);
//     }
//   }

//   @override
//   void listen(listener) {
//     // TODO: implement listen
//   }

//   @override
//   void notifyListeners() {
//     // TODO: implement notifyListeners
//   }

//   @override
//   void unlisten(listener) {
//     // TODO: implement unlisten
//   }

//   @override
//   void run() {}
// }
