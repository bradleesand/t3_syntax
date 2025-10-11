import 'package:markdown/markdown.dart' as md;
import 'package:tabletoptown/utilities/t3_syntax/content_node_ref.dart';

class StatLinkSyntax extends md.InlineSyntax {
  StatLinkSyntax() : super(regexPattern, startCharacter: startFlag.codeUnitAt(0));

  static const String _base64Regex = '[-A-Za-z0-9+/]*={0,3}';
  static const String startFlag = '{{t3stat:';
  static const String endFlag = '}}';
  static const String regexPattern = '$startFlag($_base64Regex)$endFlag';
  static const String tag = 't3stat';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final payload = ContentNodeRef.decode(match[1]!);

    if (payload == null) {
      parser.advanceBy(match[0]!.length);
      return false;
    }

    // Create an empty element because the children will be resolved later
    final node = md.Element.empty(tag);
    node.attributes['source'] = match[0]!;
    node.attributes['payload'] = match[1]!;
    node.attributes['rootId'] = payload.rootId;
    node.attributes['nodeId'] = payload.nodeId;
    final gameId = payload.gameId;
    if (gameId != null) {
      node.attributes['gameId'] = gameId;
    }

    parser.addNode(node);

    return true;
  }

  static String encode(ContentNodeRef payload) {
    final encoded = payload.encode();
    return '$startFlag$encoded$endFlag';
  }
}
