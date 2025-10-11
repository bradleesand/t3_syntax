import 'package:collection/collection.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:tabletoptown/utilities/t3_syntax/t3_syntax_parser.dart';

class MathExpressionSyntax extends md.InlineSyntax {
  MathExpressionSyntax() : super(regexPattern, startCharacter: startFlag.codeUnitAt(0));

  static const String startFlag = '{{';
  static const String endFlag = '}}';
  static const String regexPattern = '$startFlag(.*)$endFlag';
  static const String tag = 't3math';

  /// Returns the index of the closure of the tag opening at `start`.
  // Copied from function_tree package "indexOfClosingParenthesis()" utility function
  int indexOfClosingTag(String expression, [int start = 0, String open = '{{', String close = '}}']) {
    int level = 0, index;
    for (index = start; index < expression.length; index++) {
      if (expression.substring(index, index + open.length) == open) {
        level++;
        index += open.length - 1;
      } else if (expression.substring(index, index + close.length) == close) {
        level--;
        if (level == 0) {
          break;
        }
        index += close.length - 1;
      }
    }
    return level == 0 ? index : -1;
  }

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    startMatchPos ??= parser.pos;

    if (!parser.source.startsWith(startFlag, startMatchPos)) {
      return false;
    }

    final closerIndex = indexOfClosingTag(parser.source, startMatchPos, startFlag, endFlag);
    if (closerIndex == -1) {
      return false;
    }

    // Write any existing plain text up to this point.
    parser.writeText();

    // Build pattern to extract expression based on length.
    // (This is just so we can use the standard InlineSyntax pattern of onMatch.)
    final pattern = RegExp('{{(.{${closerIndex - startMatchPos - startFlag.length}})}}');
    final startMatch = pattern.matchAsPrefix(parser.source, startMatchPos);
    if (startMatch == null) {
      return false;
    }

    if (onMatch(parser, startMatch)) {
      parser.consume(startMatch[0]!.length);
    }

    return true;
  }

  static String encode(String expression) {
    return '$startFlag$expression$endFlag';
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final children = T3SyntaxParser.parseText(match[1]);

    final firstChild = children.firstOrNull;
    final firstText = (firstChild is md.Text) ? firstChild : null;
    String firstTextContent = firstText?.text ?? '';

    final roundingOption = RoundingOptionParser(firstTextContent)..parse();
    firstTextContent = roundingOption.expression;

    final formatOption = FormatOptionParser(firstTextContent)..parse();
    firstTextContent = formatOption.expression;

    if (firstText != null) {
      children[0] = md.Text(firstTextContent);
    }

    final node = md.Element(tag, children);
    node.attributes['source'] = match[0]!;
    if (roundingOption.option != null) {
      node.attributes['round'] = roundingOption.option!;
    }
    if (formatOption.option != null) {
      node.attributes['format'] = formatOption.option!;
    }

    parser.addNode(node);

    return true;
  }
}

class RoundingOptionParser {
  RoundingOptionParser(this.originalExpression);

  final String originalExpression;

  late String? option;
  late String expression;

  void parse() {
    final match = RegExp(r'round\s*:\s*(up|down)').firstMatch(originalExpression);
    if (match == null) {
      option = null;
      expression = originalExpression;
      return;
    }
    option = match[1];
    expression = originalExpression.replaceFirst(match[0]!, '');
  }
}

class FormatOptionParser {
  FormatOptionParser(this.originalExpression);

  final String originalExpression;

  late String? option;
  late String expression;

  static const pattern = 'format' // literal "format"
      r'\s*' // optional space
      ':' // literal ":"
      r'\s*' // optional space
      '(?:' // begin non-capturing group for format pattern
      // quoted pattern
      '"' // begin literal quote
      '(' // begin capture group 1 to capture quoted pattern
      '(?:' // begin non-capture group for any character except quotes and escaped quotes
      '[^"]|' // anything except a quote, OR...
      r'(?<=\\)"' // use lookbehind to match escaped quotes
      ')*' // allow zero or more characters within quotes
      ')' // end capture group 1
      '"' // end literal quote
      '|' // or
      // non-quoted pattern
      '(' // begin capture group 2 to capture non-quoted pattern
      '(?:' // being non-capture group for any character except non-escaped quote or space
      // ignore: missing_whitespace_between_adjacent_strings
      '[^" ]|' // anything except a quote or space, OR....
      // ignore: missing_whitespace_between_adjacent_strings
      r'(?<=\\)[ "]' // use lookbehind to match escaped quotes or spaces
      ')+' // at least one character required for non-quoted pattern
      ')' // end capture group 2
      ')' // end non-capturing group for format pattern
      r'\s+'; // followed by at least one space

  void parse() {
    final match = RegExp(pattern).firstMatch(originalExpression);
    if (match == null) {
      option = null;
      expression = originalExpression;
      return;
    }
    // match[1] is the quoted pattern, match[2] is the non-quoted pattern
    // only one of them will be non-null
    option = match[1] ?? match[2];
    option = option?.replaceAll(r'\"', '"');
    expression = originalExpression.replaceFirst(match[0]!, '');
  }
}
