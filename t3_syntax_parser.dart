import 'package:flutter/foundation.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:tabletoptown/content_builder/models/m_content_box.dart';
import 'package:tabletoptown/utilities/t3_syntax/math_expression_syntax.dart';
import 'package:tabletoptown/utilities/t3_syntax/stat_link_syntax.dart';
import 'package:tabletoptown/utilities/t3_syntax/value_syntax.dart';

class T3SyntaxParser {
  static List<md.Node> parseText(
    String? text, {
    // Allow syntaxes to be overridden
    List<md.InlineSyntax>? inlineSyntaxes,
  }) {
    if (text == null || text.isEmpty) {
      return [];
    }
    inlineSyntaxes ??= [
      StatLinkSyntax(),
      ValueSyntax(),
      // Check for math expressions last because they could match other syntaxes.
      MathExpressionSyntax(),
    ];
    final nodes = md.Document(
      inlineSyntaxes: inlineSyntaxes,
      encodeHtml: false,
      withDefaultBlockSyntaxes: false,
      withDefaultInlineSyntaxes: false,
    ).parseInline(text);

    return nodes;
  }

  static List<md.Node> parseStat(MContentBoxBuilder statBuilder) {
    assert(statBuilder.isStat);

    final text = statBuilder.payload.title?.trim();

    return parseText(text);
  }

  static List<md.Node> parse(MContentBoxBuilder builder) {
    if (builder.isStat) {
      return parseStat(builder);
    } else {
      if (kDebugMode) {
        throw Exception('Unexpected builder type ${builder.payload.type}');
      }
      return parseText(builder.payload.title);
    }
  }

  static bool isSupported(MContentBoxBuilder builder) => builder.isStat;
}
