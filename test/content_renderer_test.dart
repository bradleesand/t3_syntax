import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:t3_graphql/scalar.dart';
import 'package:tabletoptown/content_builder/models/m_content_box.dart';
import 'package:tabletoptown/content_builder/providers/content_box_provider.dart';
import 'package:tabletoptown/utilities/t3_syntax/content_renderer.dart';

final _getIt = GetIt.instance;

void main() {
  group('ContentBoxRenderer', () {
    setUp(() => _getIt.pushNewScope());
    tearDown(() => _getIt.popScope());

    const rootId = Uuid('1');
    const linkedNodeId = '2';
    // final linkTag = StatLinkSyntax.encode(ContentNodeRef(rootId: rootId.toString(), nodeId: linkedNodeId));
    const linkTag = '{{t3stat:eyJyb290SWQiOiIxIiwibm9kZUlkIjoiMiIsImdhbWVJZCI6bnVsbH0=}}';
    int idCounter = 3;

    // final valueTag = ValueSyntax.encode(ContentNodeValue(title: 'value', value: '42'));
    const valueTag = '{{t3value:eyJ0aXRsZSI6InZhbHVlIiwidmFsdWUiOiI0MiIsInJlZiI6bnVsbH0=}}';

    MContentBoxBuilder buildStat(String title, {String? id}) {
      id ??= (idCounter++).toString();
      return MContentBoxBuilder(
        id: MContentBoxBuilderId(id: Uuid(id)),
        payload: MContentPayloadBuilder(
          type: ContentBoxType.element,
          elementType: ContentElementValueType.number,
          title: title,
        ),
      );
    }

    test('simple text', () async {
      final treeProvider = FakeContentTreesProvider({});
      _getIt.registerSingleton<ContentTreesProvider>(treeProvider);
      final statBuilder = buildStat('hello');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, 'hello');
    });

    test('simple number', () async {
      final treeProvider = FakeContentTreesProvider({});
      _getIt.registerSingleton<ContentTreesProvider>(treeProvider);
      final statBuilder = buildStat('42');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, '42');
    });

    test('divide by zero', () async {
      final treeProvider = FakeContentTreesProvider({});
      _getIt.registerSingleton<ContentTreesProvider>(treeProvider);
      final statBuilder = buildStat('1 / 0');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, '∞');
    });

    test('zero divided by zero', () async {
      final treeProvider = FakeContentTreesProvider({});
      _getIt.registerSingleton<ContentTreesProvider>(treeProvider);
      final statBuilder = buildStat('0 / 0');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, 'NaN');
    });

    test('decimal number', () async {
      final treeProvider = FakeContentTreesProvider({});
      _getIt.registerSingleton<ContentTreesProvider>(treeProvider);
      final statBuilder = buildStat('42.12345');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, '42.12');
    });

    test('decimal number round up', () async {
      final treeProvider = FakeContentTreesProvider({});
      _getIt.registerSingleton<ContentTreesProvider>(treeProvider);
      final statBuilder = buildStat('42.125');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, '42.13');
    });

    test('zero decimal number', () async {
      final treeProvider = FakeContentTreesProvider({});
      _getIt.registerSingleton<ContentTreesProvider>(treeProvider);
      final statBuilder = buildStat('42.0');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, '42');
    });

    test('simple negative number', () async {
      final treeProvider = FakeContentTreesProvider({});
      _getIt.registerSingleton<ContentTreesProvider>(treeProvider);
      final statBuilder = buildStat('-42');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, '-42');
    });

    test('simple positive number', () async {
      final treeProvider = FakeContentTreesProvider({});
      _getIt.registerSingleton<ContentTreesProvider>(treeProvider);
      final statBuilder = buildStat('+42');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, '+42');
    });

    test('simple addition', () async {
      final treeProvider = FakeContentTreesProvider({});
      _getIt.registerSingleton<ContentTreesProvider>(treeProvider);
      final statBuilder = buildStat('1 + 2');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, '3');
    });

    test('simple reference', () async {
      final linkedNode = buildStat('42', id: linkedNodeId);
      final treeProvider = FakeContentTreesProvider({
        rootId: FakeContentBoxProvider(rootId, [linkedNode]),
      });
      _getIt.registerSingleton<ContentTreesProvider>(treeProvider);
      final statBuilder = buildStat(linkTag);
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, '42');
    });

    // this test is important to show that the resolver is resolving each reference before substituting
    // the value into the expression
    // We want to evaluate this as 1 - (1 + 2) = -2, not as 1 - 1 + 2 = 2
    test('implicit parentheses', () async {
      final linkedNode = buildStat('1 + 2', id: linkedNodeId);
      final treeProvider = FakeContentTreesProvider({
        rootId: FakeContentBoxProvider(rootId, [linkedNode]),
      });
      _getIt.registerSingleton<ContentTreesProvider>(treeProvider);

      final statBuilder = buildStat('1 - $linkTag');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, '-2');
    });

    test('add units', () async {
      final linkedNode = buildStat('1 + 2', id: linkedNodeId);
      final treeProvider = FakeContentTreesProvider({
        rootId: FakeContentBoxProvider(rootId, [linkedNode]),
      });
      _getIt.registerSingleton<ContentTreesProvider>(treeProvider);

      final statBuilder = buildStat('$linkTag units');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, '3 units');
    });

    test('units in string does not resolve', () async {
      final statBuilder = buildStat('1 + 2 units');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, '1 + 2 units');
    });

    test('units outside brackets', () async {
      final statBuilder = buildStat('{{1 + 2}} units');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, '3 units');
    });

    test('brackets include link', () async {
      final linkedNode = buildStat('1 + 2', id: linkedNodeId);
      final treeProvider = FakeContentTreesProvider({
        rootId: FakeContentBoxProvider(rootId, [linkedNode]),
      });
      _getIt.registerSingleton<ContentTreesProvider>(treeProvider);

      final statBuilder = buildStat('{{1 - $linkTag}} units');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, '-2 units');
    });

    test('brackets include invalid expression', () async {
      final statBuilder = buildStat('{{1 number}} units');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, '1 number units');
    });

    test('brackets include link with invalid expression', () async {
      final linkedNode = buildStat('1 number', id: linkedNodeId);
      final treeProvider = FakeContentTreesProvider({
        rootId: FakeContentBoxProvider(rootId, [linkedNode]),
      });
      _getIt.registerSingleton<ContentTreesProvider>(treeProvider);

      final statBuilder = buildStat('{{1 - $linkTag}} units');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, '1 - 1 number units');
    });

    test('async loading', () async {
      final linkedNode = buildStat('42', id: linkedNodeId);
      final boxProvider = FakeContentBoxProvider(rootId, [linkedNode], loading: true);
      final treeProvider = FakeContentTreesProvider({
        rootId: boxProvider,
      });
      _getIt.registerSingleton<ContentTreesProvider>(treeProvider);
      final statBuilder = buildStat(linkTag);
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final futureValue = resolver.render();

      try {
        await futureValue.timeout(const Duration(milliseconds: 1));
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<TimeoutException>());
      }

      boxProvider.loading = false;

      expect(await futureValue, '42');
    });

    test('with value tag', () async {
      final statBuilder = buildStat('$valueTag units');
      final resolver = ContentBoxRenderer(
        builder: statBuilder,
      );
      final value = await resolver.render();

      expect(value, '42 units');
    });

    group('rounding', () {
      group('round up', () {
        test('1.1', () async {
          final statBuilder = buildStat('{{round:up 1.1}}');
          final resolver = ContentBoxRenderer(
            builder: statBuilder,
          );
          final value = await resolver.render();

          expect(value, '2');
        });
        test('1.5', () async {
          final statBuilder = buildStat('{{round:up 1.5}}');
          final resolver = ContentBoxRenderer(
            builder: statBuilder,
          );
          final value = await resolver.render();

          expect(value, '2');
        });
        test('1.9', () async {
          final statBuilder = buildStat('{{round:up 1.9}}');
          final resolver = ContentBoxRenderer(
            builder: statBuilder,
          );
          final value = await resolver.render();

          expect(value, '2');
        });
      });
      group('round down', () {
        test('1.1', () async {
          final statBuilder = buildStat('{{round:down 1.1}}');
          final resolver = ContentBoxRenderer(
            builder: statBuilder,
          );
          final value = await resolver.render();

          expect(value, '1');
        });
        test('1.5', () async {
          final statBuilder = buildStat('{{round:down 1.5}}');
          final resolver = ContentBoxRenderer(
            builder: statBuilder,
          );
          final value = await resolver.render();

          expect(value, '1');
        });
        test('1.9', () async {
          final statBuilder = buildStat('{{round:down 1.9}}');
          final resolver = ContentBoxRenderer(
            builder: statBuilder,
          );
          final value = await resolver.render();

          expect(value, '1');
        });
      });
      group('default rounding', () {
        test('1.1', () async {
          final statBuilder = buildStat('{{format:# 1.1}}');
          final resolver = ContentBoxRenderer(
            builder: statBuilder,
          );
          final value = await resolver.render();

          expect(value, '1');
        });
        test('1.5', () async {
          final statBuilder = buildStat('{{format:# 1.5}}');
          final resolver = ContentBoxRenderer(
            builder: statBuilder,
          );
          final value = await resolver.render();

          expect(value, '2');
        });
        test('1.9', () async {
          final statBuilder = buildStat('{{format:# 1.9}}');
          final resolver = ContentBoxRenderer(
            builder: statBuilder,
          );
          final value = await resolver.render();

          expect(value, '2');
        });
      });

      test('embedded rounding in formatted expression', () async {
        final statBuilder = buildStat('{{format:#.00 {{round:up 1.69}} + 1.5}}');
        final resolver = ContentBoxRenderer(
          builder: statBuilder,
        );
        final value = await resolver.render();

        expect(value, '3.50');
      });

      test('embedded rounding in unformatted expression', () async {
        final statBuilder = buildStat('{{round:up 1.5}} + 1.5');
        final resolver = ContentBoxRenderer(
          builder: statBuilder,
        );
        final value = await resolver.render();

        expect(value, '3.5');
      });

      test('rounding with suffix', () async {
        final statBuilder = buildStat('{{round:up 1.5}} units');
        final resolver = ContentBoxRenderer(
          builder: statBuilder,
        );
        final value = await resolver.render();

        expect(value, '2 units');
      });
    });

    group('formatting', () {
      test('without quotes', () async {
        final statBuilder = buildStat('{{format:0.00 1.1}}');
        final resolver = ContentBoxRenderer(
          builder: statBuilder,
        );
        final value = await resolver.render();

        expect(value, '1.10');
      });

      test('with quotes', () async {
        final statBuilder = buildStat('{{format:"0.00" 1.1}}');
        final resolver = ContentBoxRenderer(
          builder: statBuilder,
        );
        final value = await resolver.render();

        expect(value, '1.10');
      });

      test('with space and quotes', () async {
        final statBuilder = buildStat('{{format:"+ 0.00;- 0.00" 1.1}}');
        final resolver = ContentBoxRenderer(
          builder: statBuilder,
        );
        final value = await resolver.render();

        expect(value, '+ 1.10');
      });

      test('with escaped quotes', () async {
        final statBuilder = buildStat(r'{{format:"0.00\"bar\"" 1.1}}');
        final resolver = ContentBoxRenderer(
          builder: statBuilder,
        );
        final value = await resolver.render();

        expect(value, '1.10"bar"');
      });

      test('with rounding', () async {
        final statBuilder = buildStat('{{round:up format:"0.00" 1.1}}');
        final resolver = ContentBoxRenderer(
          builder: statBuilder,
        );
        final value = await resolver.render();

        expect(value, '2.00');
      });
    });
  });
}

class FakeContentTreesProvider extends Fake implements ContentTreesProvider {
  FakeContentTreesProvider(this._trees);

  final Map<Uuid, ContentBoxProvider> _trees;

  @override
  ContentBoxProvider read(Uuid rootId) {
    assert(_trees.containsKey(rootId), 'No tree found for $rootId');
    return _trees[rootId]!;
  }

  @override
  ContentBoxProvider watch(Uuid rootId) {
    return read(rootId);
  }

  @override
  void registerRoot(Uuid rootId) {}

  @override
  void unregisterRoot(Uuid rootId) {}
}

class FakeContentBoxProvider extends Fake implements ContentBoxProvider {
  FakeContentBoxProvider(
    this.rootId,
    List<MContentBoxBuilder> nodes, {
    bool loading = false,
  })  : _nodes = Map.fromEntries(nodes.map((node) => MapEntry(node.id, node))),
        _loading = loading;

  final ChangeNotifier _notifier = ChangeNotifier();

  final Uuid rootId;
  final Map<MContentBoxBuilderId, MContentBoxBuilder> _nodes;

  bool _loading;

  void addNode(MContentBoxBuilder node) {
    _nodes[node.id] = node;
  }

  @override
  MContentBoxBuilder? node(MContentBoxBuilderId id) => _nodes[id];

  @override
  bool get loading => _loading;

  @override
  set loading(bool value) {
    _loading = value;
    _notifier.notifyListeners();
  }

  @override
  void notifyListeners() {
    _notifier.notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    _notifier.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _notifier.removeListener(listener);
  }
}
