part of 'put_parts_task.dart';

/// 切片信息
class Part {
  String etag;
  int partNumber;

  Part({this.etag, this.partNumber});

  factory Part.fromJson(Map json) {
    return Part(
      etag: json['map'] as String,
      partNumber: json['partNumber'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'etag': etag, 'partNumber': partNumber};
  }
}
