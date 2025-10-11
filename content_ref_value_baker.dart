import 'package:markdown/markdown.dart' as md;
import 'package:tabletoptown/utilities/t3_syntax/content_math_resolver.dart';
import 'package:tabletoptown/utilities/t3_syntax/content_node_ref.dart';
import 'package:tabletoptown/utilities/t3_syntax/content_node_value.dart';
import 'package:tabletoptown/utilities/t3_syntax/content_ref_resolver.dart';
import 'package:tabletoptown/utilities/t3_syntax/stat_link_syntax.dart';
import 'package:tabletoptown/utilities/t3_syntax/t3_syntax_parser.dart';
import 'package:tabletoptown/utilities/t3_syntax/value_syntax.dart';

class ContentRefValueBaker {
  static Future<String> bake(String value) async {
    // Only parse with StatLinkSyntax because we want to resolve the content refs.
    final nodes = T3SyntaxParser.parseText(value, inlineSyntaxes: [StatLinkSyntax()]);
    final contentRefResolver = ContentRefResolver(watch: false);
    final resolvedNodes = await contentRefResolver.resolve(nodes);

    final buffer = StringBuffer();

    for (final node in resolvedNodes) {
      if (node is md.Element) {
        switch (node.tag) {
          case StatLinkSyntax.tag:
            // This node should have been expanded by ContentRefResolver so we want to resolve the children and bake in
            // the value.
            buffer.write(
              ValueSyntax.encode(
                ContentNodeValue(
                  title: node.attributes['title'],
                  value: ContentMathResolver().resolve(node.children!),
                  ref: ContentNodeRef(
                    rootId: node.attributes['rootId']!,
                    nodeId: node.attributes['nodeId']!,
                    gameId: node.attributes['gameId'],
                  ),
                ),
              ),
            );
            break;
          default:
            throw Exception('Unexpected tag: ${node.tag}');
        }
      } else {
        buffer.write(node.textContent);
      }
    }

    return buffer.toString();
  }
}
