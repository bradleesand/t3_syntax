import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:tabletoptown/utilities/t3_syntax/content_node_ref.dart';
import 'package:tabletoptown/utilities/t3_syntax/stat_link_syntax.dart';
import 'package:tabletoptown/utilities/t3_syntax/t3_syntax_parser.dart';

void main() {
  group('T3SyntaxParser', () {
    test('empty string', () {
      expect(T3SyntaxParser.parseText(''), <md.Node>[]);
    });

    test('null string', () {
      expect(T3SyntaxParser.parseText(null), <md.Node>[]);
    });

    test('text without syntax', () {
      expect(
        T3SyntaxParser.parseText('text without syntax'),
        MatchesNodes([
          md.Text('text without syntax'),
        ]),
      );
    });

    test('text with link', () {
      final statLink = StatLinkSyntax.encode(ContentNodeRef(rootId: '1', nodeId: '2'));

      final linkElement = md.Element.empty(StatLinkSyntax.tag);
      linkElement.attributes['source'] = statLink;
      linkElement.attributes['payload'] = statLink.substring('{{t3stat:'.length, statLink.length - '}}'.length);
      linkElement.attributes['rootId'] = '1';
      linkElement.attributes['nodeId'] = '2';

      expect(
        T3SyntaxParser.parseText('text with $statLink syntax'),
        MatchesNodes([
          md.Text('text with '),
          linkElement,
          md.Text(' syntax'),
        ]),
      );
    });

    group('MathExpressionSyntax', () {
      test('text with math expression', () {
        expect(
          T3SyntaxParser.parseText('text with {{1+1}} syntax'),
          MatchesNodes(
            [
              md.Text('text with '),
              md.Element('t3math', [
                md.Text('1+1'),
              ]),
              md.Text(' syntax'),
            ],
            ignoreAttributes: true,
          ),
        );
      });

      test('link in math expression', () {
        final statLink = StatLinkSyntax.encode(ContentNodeRef(rootId: '1', nodeId: '2'));

        final linkElement = md.Element.empty(StatLinkSyntax.tag);
        linkElement.attributes['source'] = statLink;
        linkElement.attributes['payload'] = statLink.substring('{{t3stat:'.length, statLink.length - '}}'.length);
        linkElement.attributes['rootId'] = '1';
        linkElement.attributes['nodeId'] = '2';

        expect(
          T3SyntaxParser.parseText('text with {{1+1+$statLink}} syntax'),
          MatchesNodes(
            [
              md.Text('text with '),
              md.Element('t3math', [
                md.Text('1+1+'),
                linkElement,
              ]),
              md.Text(' syntax'),
            ],
            ignoreAttributes: true,
          ),
          reason: 'The link should be parsed as a child of the math expression',
        );
      });
    });
  });
}

class MatchesNodes extends CustomMatcher {
  MatchesNodes(
    List<md.Node> nodes, {
    this.ignoreAttributes = false,
  }) : super('Matches nodes', 'nodes', equals(nodeListToString(nodes)));

  final bool ignoreAttributes;

  @override
  Object? featureValueOf(actual) {
    if (actual is List<md.Node>) {
      return nodeListToString(actual, ignoreAttributes: ignoreAttributes);
    }
    return null;
  }

  static String nodeListToString(List<md.Node> nodes, {bool ignoreAttributes = false}) =>
      nodes.map((n) => nodeToString(n, ignoreAttributes: ignoreAttributes)).join();

  // This just writes the node as an XML-like string for easy string comparison
  static String nodeToString(md.Node node, {bool ignoreAttributes = false}) {
    if (node is md.Text) {
      return node.text;
    } else if (node is md.Element) {
      final builder = StringBuffer();
      builder.write('<${node.tag}');
      if (!ignoreAttributes && node.attributes.isNotEmpty) {
        builder.write(' ');
        builder.writeAll(node.attributes.entries.map((e) => '${e.key}="${e.value}"'), ' ');
      }
      builder.write('>');
      if (node.children?.isNotEmpty == true) {
        builder.write(node.children!.map((node) => nodeToString(node)).join());
      }
      builder.write('</${node.tag}>');
      return builder.toString();
    } else {
      return '';
    }
  }
}
