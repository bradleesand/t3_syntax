import 'dart:convert';

class ContentNodeRef {
  ContentNodeRef({
    required this.rootId,
    required this.nodeId,
    this.gameId,
  });

  final String rootId;
  final String nodeId;
  final String? gameId;

  static ContentNodeRef? fromJson(Map<String, dynamic> json) {
    final rootId = json['rootId'];
    final nodeId = json['nodeId'];
    final gameId = json['gameId'];

    if (rootId is! String || nodeId is! String || gameId is! String?) {
      return null;
    }

    return ContentNodeRef(
      rootId: rootId,
      nodeId: nodeId,
      gameId: gameId,
    );
  }

  Map<String, dynamic> toJson() => {
        'rootId': rootId,
        'nodeId': nodeId,
        'gameId': gameId,
      };

  String encode() => base64Encode(utf8.encode(jsonEncode(toJson())));

  static ContentNodeRef? decode(String text) {
    final json = jsonDecode(utf8.decode(base64Decode(text)));
    if (json is! Map<String, dynamic>) {
      return null;
    }
    return ContentNodeRef.fromJson(json);
  }
}
