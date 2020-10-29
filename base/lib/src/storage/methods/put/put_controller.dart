import '../../task/request_task.dart'
    show RequestTaskProgressListener, RequestTaskStatusListener, RequestTask;
import 'put_response.dart';

class PutController {
  final RequestTask<PutResponse> _task;
  const PutController(this._task);

  Future<PutResponse> get future => _task.future;

  void Function() addProgressListener(RequestTaskProgressListener listener) {
    return _task.addProgressListener(listener);
  }

  void Function() addStatusListener(RequestTaskStatusListener listener) {
    return _task.addStatusListener(listener);
  }

  void cancel() {
    _task.cancel();
  }
}
