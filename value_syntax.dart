import 'package:markdown/markdown.dart' as md;
import 'package:tabletoptown/utilities/t3_syntax/content_node_value.dart';

class ValueSyntax extends md.InlineSyntax {
  ValueSyntax() : super(regexPattern, startCharacter: startFlag.codeUnitAt(0));

  static const String _base64Regex = '[-A-Za-z0-9+/]*={0,3}';
  static const String startFlag = '{{t3value:';
  static const String endFlag = '}}';
  static const String regexPattern = '$startFlag($_base64Regex)$endFlag';
  static const String tag = 't3value';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final payload = ContentNodeValue.decode(match[1]!);

    if (payload == null) {
      parser.advanceBy(match[0]!.length);
      return false;
    }

    final rootId = payload.ref?.rootId;
    final nodeId = payload.ref?.nodeId;
    final gameId = payload.ref?.gameId;

    final node = md.Element.empty(tag);
    node.attributes['source'] = match[0]!;
    node.attributes['payload'] = match[1]!;
    if (payload.title != null) {
      node.attributes['title'] = payload.title!;
    }
    if (payload.value != null) {
      node.attributes['value'] = payload.value!;
    }
    if (rootId != null) {
      node.attributes['rootId'] = rootId;
    }
    if (nodeId != null) {
      node.attributes['nodeId'] = nodeId;
    }
    if (gameId != null) {
      node.attributes['gameId'] = gameId;
    }

    parser.addNode(node);

    return true;
  }

  static String encode(ContentNodeValue payload) {
    final encoded = payload.encode();
    return '$startFlag$encoded$endFlag';
  }
}
