import 'dart:math';

final random = Random();

extension ListRandomSelect<T> on List<T> {
  T mustGetRandomElement() {
    return elementAt(random.nextInt(length));
  }
}
