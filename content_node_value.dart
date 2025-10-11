import 'dart:convert';

import 'package:tabletoptown/utilities/t3_syntax/content_node_ref.dart';

class ContentNodeValue {
  ContentNodeValue({
    required this.title,
    required this.value,
    this.ref,
  });

  final String? title;
  final String? value;
  final ContentNodeRef? ref;

  static ContentNodeValue? fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final value = json['value'];
    final refJson = json['ref'];
    if ((refJson is! Map<String, dynamic>?) || (title is! String?) || (value is! String?)) {
      return null;
    }

    final ref = refJson != null ? ContentNodeRef.fromJson(refJson) : null;

    return ContentNodeValue(
      title: title,
      value: value,
      ref: ref,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'value': value,
        'ref': ref?.toJson(),
      };

  String encode() => base64Encode(utf8.encode(jsonEncode(toJson())));

  static ContentNodeValue? decode(String text) {
    final json = jsonDecode(utf8.decode(base64Decode(text)));
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return ContentNodeValue.fromJson(json);
  }
}
