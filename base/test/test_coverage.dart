import 'auth/auth_test.dart' as auth_test;
import 'config_test.dart' as config_test;
import 'put/put_by_parts/put_bytes_test.dart' as put_by_part_bytes_test;
import 'put/put_by_parts/put_file_test.dart' as put_by_part_file_test;
import 'put/put_by_single/put_bytes.dart' as put_by_single_bytes_test;
import 'put/put_by_single/put_file.dart' as put_by_single_file_test;
import 'resource_test.dart' as resource_test;
import 'retry_test.dart' as retry_test;

void main() {
  auth_test.main();
  config_test.main();
  retry_test.main();
  put_by_part_bytes_test.main();
  put_by_part_file_test.main();
  put_by_single_bytes_test.main();
  put_by_single_file_test.main();
  resource_test.main();
}
