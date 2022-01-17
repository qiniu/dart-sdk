import 'auth/auth_test.dart' as auth_test;
import 'config_test.dart' as config_test;
import 'put/put_by_part_test.dart' as put_by_part_test;
import 'put/put_by_single_test.dart' as put_by_single_test;
import 'put/put_controller_test.dart' as put_controller_test;
import 'put/put_task_test.dart' as put_task_test;
import 'resource_test.dart' as resource_test;
import 'retry_test.dart' as retry_test;

void main() {
  auth_test.main();
  config_test.main();
  retry_test.main();
  put_by_part_test.main();
  put_by_single_test.main();
  put_controller_test.main();
  put_task_test.main();
  resource_test.main();
}
