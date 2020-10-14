part of 'config.dart';

enum Protocol { Http, Https }

extension ProtocolExt on Protocol {
  String get value {
    if (this == Protocol.Http) return 'http';
    if (this == Protocol.Https) return 'https';
    return 'https';
  }
}
