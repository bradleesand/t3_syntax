import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get_it/get_it.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import 'package:scrapbook_flutter/scrapbook_flutter.dart';
import 'package:t3_graphql/scalar.dart';
import 'package:tabletoptown/content_builder/models/m_content_box.dart';
import 'package:tabletoptown/content_builder/providers/content_box_provider.dart';
import 'package:tabletoptown/utilities/t3_syntax/content_math_resolver.dart';
import 'package:tabletoptown/utilities/t3_syntax/content_node_ref.dart';
import 'package:tabletoptown/utilities/t3_syntax/content_ref_resolver.dart';
import 'package:tabletoptown/utilities/t3_syntax/t3_syntax_parser.dart';

AsyncSnapshot<String> useRenderContentBox(
  MContentBoxBuilder? builder,
) {
  return _useRenderContent(
    () => builder == null ? null : ContentBoxRenderer(builder: builder),
    [builder],
  );
}

AsyncSnapshot<String> useRenderContentText(
  String? text,
) {
  return _useRenderContent(
    () => text == null ? null : ContentTextRenderer(text: text),
    [text],
  );
}

typedef _RendererBuilder = ContentRenderer? Function();

AsyncSnapshot<String> _useRenderContent(
  _RendererBuilder rendererBuilder,
  List<Object?> rendererBuilderKeys,
) {
  final context = useContext();
  final contentTreesProvider = context.watch<ContentTreesProvider>();

  // We need to be able to invalidate the resolver when the any of the dependent roots change.
  // To do this, we use a version number that is incremented whenever a root changes.
  // This is a hacky solution, but it works.
  // The reason this is needed is because the resolver needs to be able to run once to get the list of roots and then
  // when any of those roots change we need to build a new resolver.
  // The main use case for this is when a stat is being used for the quick data on a Piece.
  final version = useState(0);
  final isMounted = useIsMounted();

  final renderer = useMemoized(
    rendererBuilder,
    [version.value, contentTreesProvider, ...rendererBuilderKeys],
  );

  final statsToWatch = useFuture(renderer?.nodesToWatch);

  final providersToWatch = useMemoized(
    () => statsToWatch.data
        ?.map((e) => e.rootId)
        .toSet()
        .map((rootId) => contentTreesProvider.read(Uuid(rootId))) // we can just read bc these are already being watched
        .toList(),
    [...statsToWatch.data ?? []],
  );

  final listListener = useListListener<ContentBoxProvider>(providersToWatch ?? []);

  useEffect(
    () {
      void listener() {
        if (isMounted()) {
          version.value++;
        }
      }

      listListener.addListener(listener);
      return () {
        listListener.removeListener(listener);
      };
    },
    [listListener],
  );

  final futureString = useMemoized(
    () => renderer?.tryRender(),
    [renderer],
  );

  useEffect(
    () {
      // unregister roots as cleanup
      return renderer?.unregisterRoots;
    },
    [renderer],
  );

  return useFuture(futureString, preserveState: false);
}

class ContentBoxRenderer extends ContentRenderer {
  ContentBoxRenderer({
    required this.builder,
    super.watch,
  });

  final MContentBoxBuilder builder;

  @override
  List<md.Node> parseNodes() => T3SyntaxParser.parse(builder);

  @override
  bool isSupported() => T3SyntaxParser.isSupported(builder);
}

class ContentTextRenderer extends ContentRenderer {
  ContentTextRenderer({
    required this.text,
    super.watch,
  });

  final String text;

  @override
  List<md.Node> parseNodes() => T3SyntaxParser.parseText(text);

  @override
  bool isSupported() => true;
}

abstract class ContentRenderer {
  ContentRenderer({
    bool watch = true,
  }) : _refResolver = ContentRefResolver(
          watch: watch,
        );

  ContentTreesProvider get contentTreesProvider => GetIt.I<ContentTreesProvider>();

  final ContentRefResolver _refResolver;

  final Completer<String> _valueCompleter = Completer();
  Future<String> get value => _valueCompleter.future;

  // nodesToWatch and watchedRoots are only valid after all the refs have been resolved since we have no way to
  // interrupt the recursive resolver.
  Future<List<ContentNodeRef>> get nodesToWatch => value.then((_) => _refResolver.nodesToWatch);
  Future<List<String>> get watchedRoots => value.then((_) => _refResolver.watchedRoots);

  bool _started = false;

  // Abstract methods
  List<md.Node> parseNodes();
  bool isSupported();

  Future<String>? tryRender() {
    if (!isSupported()) {
      return null;
    }
    return render();
  }

  Future<String> render() async {
    if (_started) {
      return this.value;
    }

    _started = true;

    final nodes = parseNodes();

    final nodesWithRefs = await _refResolver.resolve(nodes);

    final value = ContentMathResolver().resolve(nodesWithRefs);

    _valueCompleter.complete(value);
    return value;
  }

  void unregisterRoots() {
    // Wait until the value is resolved before unregistering the roots
    watchedRoots.then(
      (roots) {
        for (final rootId in roots) {
          contentTreesProvider.unregisterRoot(Uuid(rootId));
        }
      },
    );
  }
}
