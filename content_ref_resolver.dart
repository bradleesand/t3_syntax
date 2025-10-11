import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:t3_graphql/scalar.dart';
import 'package:tabletoptown/content_builder/models/m_content_box.dart';
import 'package:tabletoptown/content_builder/providers/content_box_provider.dart';
import 'package:tabletoptown/utilities/t3_syntax/content_node_ref.dart';
import 'package:tabletoptown/utilities/t3_syntax/math_expression_syntax.dart';
import 'package:tabletoptown/utilities/t3_syntax/stat_link_syntax.dart';
import 'package:tabletoptown/utilities/t3_syntax/t3_syntax_parser.dart';
import 'package:tabletoptown/utilities/t3_syntax/value_syntax.dart';

// This class is used to resolve the references in a content text string.
// It recursively resolves the references and returns a list of nodes where children have been added to each reference
// for expansion.
class ContentRefResolver extends md.NodeVisitor {
  ContentRefResolver({
    required this.watch,
    this.ancestry = const [],
  });

  ContentTreesProvider get contentTreesProvider => GetIt.I<ContentTreesProvider>();
  final bool watch;
  final List<String> ancestry;

  final List<String> watchedRoots = [];
  final List<ContentNodeRef> nodesToWatch = [];

  late final List<Future<md.Node>> _nodes;

  Future<List<md.Node>> resolve(List<md.Node> nodes) async {
    _nodes = [];

    for (final node in nodes) {
      node.accept(this);
    }

    return Future.wait(_nodes, eagerError: true);
  }

  md.Element _copyElementWithChildren(
    md.Element element,
    List<md.Node> children, {
    Map<String, String> attributes = const {},
  }) {
    final newElement = md.Element(element.tag, [...children]);
    for (final attribute in element.attributes.entries) {
      newElement.attributes[attribute.key] = attribute.value;
    }
    for (final attribute in attributes.entries) {
      newElement.attributes[attribute.key] = attribute.value;
    }
    return newElement;
  }

  @override
  bool visitElementBefore(md.Element element) {
    switch (element.tag) {
      case ValueSyntax.tag:
        _nodes.add(Future.value(element));
        return false;

      case MathExpressionSyntax.tag:
        if (element.children?.isEmpty ?? false) {
          _nodes.add(Future.value(element));
        }

        final renderer = ContentRefResolver(
          watch: watch,
          ancestry: ancestry,
        );

        final resolvedNode = renderer.resolve(element.children!).then(
          (children) {
            watchedRoots.addAll(renderer.watchedRoots);

            return _copyElementWithChildren(element, children);
          },
        );
        _nodes.add(resolvedNode);
        return false;

      case StatLinkSyntax.tag:
        if (element.isEmpty) {
          final rootId = element.attributes['rootId'];
          final nodeId = element.attributes['nodeId'];

          if (rootId is! String || nodeId is! String) {
            return false;
          }

          final ancestryKey = '$rootId/$nodeId';

          // Check for circular reference
          if (ancestry.contains(ancestryKey)) {
            _nodes.clear();
            _nodes.add(
              Future.value(CircularReferenceNode()),
            );
            return false;
          }

          final ContentBoxProvider contentTree;
          if (watch) {
            contentTree = contentTreesProvider.watch(Uuid(rootId));
            watchedRoots.add(rootId);
          } else {
            contentTree = contentTreesProvider.read(Uuid(rootId));
          }

          // Prepare function to expand reference stat
          Future<md.Node> expandNode() async {
            final statBuilder = contentTree.node(MContentBoxBuilderId(id: Uuid(nodeId)));
            if (statBuilder == null) {
              return _copyElementWithChildren(element, [BrokenLinkNode()], attributes: {'broken': 'true'});
            }
            nodesToWatch.add(
              ContentNodeRef(
                rootId: rootId,
                nodeId: nodeId,
              ),
            );

            final renderer = ContentRefResolver(
              watch: watch,
              ancestry: [...ancestry, ancestryKey],
            );

            final children = await renderer.resolve(T3SyntaxParser.parseStat(statBuilder));
            watchedRoots.addAll(renderer.watchedRoots);

            return _copyElementWithChildren(
              element,
              children,
              attributes: {
                if (statBuilder.payload.title != null) 'title': statBuilder.payload.title!,
              },
            );
          }

          // Prepare future to be completed when ready
          final completer = Completer<md.Node>();

          // If the content tree needs to load, wait for it to load
          if (contentTree.loading) {
            late final void Function() listener;
            listener = () {
              if (!contentTree.loading) {
                completer.complete(expandNode());
                contentTree.removeListener(listener);
              }
            };
            contentTree.addListener(listener);
          } else {
            completer.complete(expandNode());
          }

          _nodes.add(completer.future);
        } else {
          _nodes.add(Future.value(element));
        }
        return false;
      default:
        throw Exception('Unexpected element ${element.tag}');
    }
  }

  @override
  void visitText(md.Text text) {
    _nodes.add(Future.value(text));
  }

  @override
  void visitElementAfter(md.Element element) {
    // do nothing
  }
}

class CircularReferenceNode extends md.Text {
  CircularReferenceNode() : super('Circular Reference');
}

class BrokenLinkNode extends md.Text {
  BrokenLinkNode() : super('Broken Link');
}
