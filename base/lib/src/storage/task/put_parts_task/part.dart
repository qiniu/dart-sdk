part of 'put_parts_task.dart';

/// 切片信息
class Part {
  final String etag;
  final int partNumber;

  Part({
    @required this.etag,
    @required this.partNumber,
  });

  factory Part.fromJson(Map<String, dynamic> json) {
    return Part(
      etag: json['map'] as String,
      partNumber: json['partNumber'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'etag': etag,
      'partNumber': partNumber,
    };
  }
}
