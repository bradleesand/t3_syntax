import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:markdown/markdown.dart' as md;
import 'package:tabletoptown/utilities/math_resolver.dart';
import 'package:tabletoptown/utilities/t3_syntax/math_expression_syntax.dart';
import 'package:tabletoptown/utilities/t3_syntax/stat_link_syntax.dart';
import 'package:tabletoptown/utilities/t3_syntax/t3_syntax_parser.dart';
import 'package:tabletoptown/utilities/t3_syntax/value_syntax.dart';

class ContentMathResolver extends md.NodeVisitor {
  late StringBuffer _buffer;
  late String _value;

  String get value => _value;

  String resolveText(String text) => resolve(T3SyntaxParser.parseText(text));

  num? resolveTextToNum(String text) => resolveToNum(T3SyntaxParser.parseText(text));

  String resolve(List<md.Node> nodes, {String? format, String? round}) {
    if (nodes.length == 1 && nodes[0] is md.Element && (nodes[0] as md.Element).tag == MathExpressionSyntax.tag) {
      // If the only node is a MathExpressionSyntax, resolve it as a string
      return resolveToString(nodes);
    }

    var resolvedValue = resolveToNum(nodes);

    if (resolvedValue == null) {
      return _value;
    }

    if (round == 'up') {
      resolvedValue = resolvedValue.ceil();
    } else if (round == 'down') {
      resolvedValue = resolvedValue.floor();
    }

    if (format == null) {
      // include plus if given, if value is positive
      final prefix = _value.trimLeft().startsWith('+') ? '+' : '';
      format = '$prefix#.##;-#.##';
    }
    return NumberFormat(format).format(resolvedValue);
  }

  String resolveToString(List<md.Node> nodes) {
    _buffer = StringBuffer();
    for (final node in nodes) {
      node.accept(this);
    }
    _value = _buffer.toString();

    return _value;
  }

  num? resolveToNum(List<md.Node> nodes) {
    return tryResolve(resolveToString(nodes));
  }

  @override
  bool visitElementBefore(md.Element element) {
    switch (element.tag) {
      case ValueSyntax.tag:
        if (element.attributes['value'] != null) {
          _buffer.write(element.attributes['value']);
        }
        return false;
      case MathExpressionSyntax.tag:
      case StatLinkSyntax.tag:
        // Resolve the children before appending them to the buffer
        if (element.children != null) {
          final format = element.attributes['format'];
          final round = element.attributes['round'];
          _buffer.write(ContentMathResolver().resolve(element.children!, format: format, round: round));
        }
        // We just visited the children with the new resolver so don't let the current vistor visit the children.
        return false;
      default:
        if (kDebugMode) {
          throw Exception('Unexpected element ${element.tag}');
        }
      // do nothing for unexpected elements
    }

    return true;
  }

  @override
  void visitElementAfter(md.Element element) {
    // do nothing
  }

  @override
  void visitText(md.Text text) {
    _buffer.write(text.textContent);
  }
}
