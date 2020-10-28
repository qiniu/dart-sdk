import './task/request_task.dart'
    show RequestTask, RequestStatusListener, ProgressListener;

class PutController<T> {
  final RequestTask<T> task;
  const PutController(this.task);

  void Function() addProgressListener(ProgressListener listener) {
    return task.addProgressListener(listener);
  }

  void Function() addStatusListener(RequestStatusListener listener) {
    return task.addStatusListener(listener);
  }

  void cancel() {
    task.cancel();
  }
}
