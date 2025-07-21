Iterable<List<T>> chunkList<T>(List<T> list, int chunkSize) sync* {
  for (int i = 0; i < list.length; i += chunkSize) {
    yield list.sublist(
      i,
      i + chunkSize > list.length ? list.length : i + chunkSize,
    );
  }
}
