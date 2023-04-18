String humanizeBigNumber(
  double value, {
  int decimal = 2,
  double radix = 1000,
  List<String> units = const <String>[
    '',
    'K',
    'M',
    'G',
    'T',
    'P',
    'E',
    'Z',
    'Y',
    'B',
    'N',
    'D',
    'C',
    'X'
  ],
}) {
  var index = 0;
  while (index < units.length - 1 && value >= radix) {
    value /= radix;
    index++;
  }

  var displayValue = value.toString();

  if (value.floor() < value) {
    displayValue = value.toStringAsFixed(decimal);
  }

  return '$displayValue ${units[index]}';
}

String humanizeFileSize(
  double value, {
  int decimal = 2,
}) {
  return '${humanizeBigNumber(value, decimal: decimal, radix: 1024)}B';
}
