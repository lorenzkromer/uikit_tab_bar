import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uikit_tab_bar/src/icon_renderer.dart';
import 'package:uikit_tab_bar/uikit_tab_bar.dart';

const _codec = StandardMethodCodec();

/// Fake native side: records platform view creation and channel calls.
class FakeNative {
  FakeNative(this.tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        viewId = args['id'] as int;
        creationParams = const StandardMessageCodec()
            .decodeMessage(ByteData.sublistView(args['params'] as Uint8List)) as Map;
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel('uikit_tab_bar/view_$viewId'), (call) async {
          calls.add(call);
          return null;
        });
      }
      return null;
    });
  }

  final WidgetTester tester;
  int? viewId;
  Map? creationParams;
  final List<MethodCall> calls = [];

  List<MethodCall> get updates => calls.where((c) => c.method == 'update').toList();
  Map get lastState => (updates.last.arguments as Map)['state'] as Map;

  /// Delivers an event from "native" to Dart.
  Future<void> send(String method, [Object? args]) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'uikit_tab_bar/view_$viewId',
      _codec.encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );
    await tester.pump();
  }
}

class _Harness extends StatefulWidget {
  const _Harness({required this.builder});
  final Widget Function(BuildContext context, void Function(VoidCallback) setState) builder;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  Widget build(BuildContext context) => widget.builder(context, setState);
}

Widget _app(Widget child) => MediaQuery(
      data: const MediaQueryData(size: Size(420, 912), padding: EdgeInsets.only(bottom: 34)),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );

const _tabs = [
  UIKitTab(id: 'home', label: 'Home', icon: UIKitTabIcon.symbol('house')),
  UIKitTab(id: 'explore', label: 'Explore', icon: UIKitTabIcon.symbol('star')),
];

void main() {
  setUp(() => debugUseNativeTabBar = true);
  tearDown(() => debugUseNativeTabBar = null);

  testWidgets('creates the view with the initial state', (tester) async {
    final native = FakeNative(tester);
    await tester.pumpWidget(_app(UIKitTabBar(tabs: _tabs, selectedId: 'explore', onSelected: (_) {})));
    await tester.pump();
    expect(native.viewId, isNotNull);
    final state = native.creationParams!['state'] as Map;
    expect(state['selectedId'], 'explore');
    expect((state['tabs'] as List).map((t) => (t as Map)['id']), ['home', 'explore']);
  });

  testWidgets('sends an update only when the state changed', (tester) async {
    final native = FakeNative(tester);
    var badge = '1';
    late void Function(VoidCallback) rebuild;
    await tester.pumpWidget(_app(_Harness(builder: (context, setState) {
      rebuild = setState;
      return UIKitTabBar(
        tabs: [
          UIKitTab(id: 'home', label: 'Home', icon: const UIKitTabIcon.symbol('house'), badge: badge),
        ],
        selectedId: 'home',
        onSelected: (_) {},
      );
    })));
    await tester.pump();
    final initial = native.updates.length;

    rebuild(() {});
    await tester.pump();
    expect(native.updates.length, initial, reason: 'identical state must not be resent');

    rebuild(() => badge = '2');
    await tester.pump();
    expect(native.updates.length, initial + 1);
    expect(((native.lastState['tabs'] as List).single as Map)['badge'], '2');
  });

  testWidgets('selection: tap reports, veto re-sends, reselect is separate', (tester) async {
    final native = FakeNative(tester);
    final selected = <String>[];
    final reselected = <String>[];
    await tester.pumpWidget(_app(UIKitTabBar(
      tabs: _tabs,
      selectedId: 'home',
      onSelected: selected.add, // never changes selectedId: a veto
      onReselect: reselected.add,
    )));
    await tester.pump();
    final before = native.updates.length;

    await native.send('selected', {'id': 'explore'});
    await tester.pump();
    expect(selected, ['explore']);
    // Native selected optimistically; Dart re-sends its state to undo it.
    expect(native.updates.length, before + 1);
    expect(native.lastState['selectedId'], 'home');

    await native.send('reselected', {'id': 'home'});
    expect(reselected, ['home']);
    expect(selected, ['explore']);
  });

  testWidgets('accepted selection is pushed', (tester) async {
    final native = FakeNative(tester);
    var current = 'home';
    await tester.pumpWidget(_app(_Harness(
      builder: (context, setState) => UIKitTabBar(
        tabs: _tabs,
        selectedId: current,
        onSelected: (id) => setState(() => current = id),
      ),
    )));
    await tester.pump();
    await native.send('selected', {'id': 'explore'});
    await tester.pump();
    expect(native.lastState['selectedId'], 'explore');
  });

  testWidgets('rendered images are sent once', (tester) async {
    final native = FakeNative(tester);
    const icon = UIKitTabIcon.icon(IconData(0x41));
    await tester.runAsync(() => IconRenderer.instance.precache([icon], 3));
    var label = 'A';
    late void Function(VoidCallback) rebuild;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(420, 912), devicePixelRatio: 3),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: _Harness(builder: (context, setState) {
          rebuild = setState;
          return UIKitTabBar(
            tabs: [UIKitTab(id: 'a', label: label, icon: icon)],
            selectedId: 'a',
            onSelected: (_) {},
          );
        }),
      ),
    ));
    await tester.pump();
    final images = native.creationParams!['images'] as Map;
    expect(images.length, 1);
    final key = images.keys.single;
    final tab = ((native.creationParams!['state'] as Map)['tabs'] as List).single as Map;
    expect(tab['icon'], {'image': key, 'scale': 3.0});

    rebuild(() => label = 'B');
    await tester.pump();
    final update = native.updates.last.arguments as Map;
    expect((update['images'] as Map), isEmpty, reason: 'native already has the image');
  });

  testWidgets('geometry updates controller and hit testing', (tester) async {
    tester.view.physicalSize = const Size(420, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final native = FakeNative(tester);
    final controller = UIKitTabBarController();
    addTearDown(controller.dispose);
    final reported = <UIKitTabBarGeometry>[];
    var behindTapped = 0;
    await tester.pumpWidget(_app(Stack(children: [
      Positioned.fill(
        child: GestureDetector(onTap: () => behindTapped++, behavior: HitTestBehavior.opaque),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: UIKitTabBar(
          tabs: _tabs,
          selectedId: 'home',
          onSelected: (_) {},
          controller: controller,
          onGeometryChanged: reported.add,
        ),
      ),
    ])));
    await tester.pump();
    await native.send('geometry', {
      'bottomInset': 83.0,
      'bar': [0.0, 117.0, 420.0, 83.0],
      'hitRects': [
        [21.0, 117.0, 378.0, 62.0],
      ],
      'minimized': false,
      'hidden': false,
      'accessoryEnvironment': 'none',
    });
    expect(controller.geometry.value.bottomInset, 83);
    expect(reported.single.hitRects.single, const Rect.fromLTWH(21, 117, 378, 62));

    // The host is 200 high at the bottom of a 912 high screen: y 712..912.
    await tester.tapAt(const Offset(210, 750)); // transparent part of the host
    expect(behindTapped, 1, reason: 'touches outside the glass reach Flutter');
    await tester.tapAt(const Offset(210, 712 + 140)); // on the bar
    expect(behindTapped, 1, reason: 'touches on the glass go to the native view');
  });

  testWidgets('forwards vertical primary scrolling with the selected tab id', (tester) async {
    final native = FakeNative(tester);
    final controller = UIKitTabBarController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(UIKitTabScaffold(
      controller: controller,
      tabBar: UIKitTabBar(tabs: _tabs, selectedId: 'explore', onSelected: (_) {}),
      body: ListView(children: [for (var i = 0; i < 50; i++) SizedBox(height: 80, child: Text('$i'))]),
    )));
    await tester.pump();
    await tester.drag(find.text('3'), const Offset(0, -300));
    await tester.pump();
    final scrolls = native.calls.where((c) => c.method == 'scroll').toList();
    expect(scrolls, isNotEmpty);
    final last = scrolls.last.arguments as Map;
    expect(last['tabId'], 'explore');
    expect(last['pixels'] as double, greaterThan(0));
    expect(last['max'] as double, greaterThan(0));
  });

  testWidgets('search and accessory events reach the callbacks', (tester) async {
    final native = FakeNative(tester);
    final texts = <String>[];
    final submitted = <String>[];
    final active = <bool>[];
    final actions = <String>[];
    var accessoryTaps = 0;
    final controller = UIKitTabBarController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(UIKitTabBar(
      tabs: _tabs,
      selectedId: 'home',
      onSelected: (_) {},
      controller: controller,
      searchTab: UIKitSearchTab(onChanged: texts.add, onSubmitted: submitted.add, onActiveChanged: active.add),
      accessory: UIKitTabAccessory(
        title: 'Now',
        onTap: () => accessoryTaps++,
        onAction: actions.add,
      ),
    )));
    await tester.pump();
    await native.send('searchActive', {'active': true});
    await native.send('searchChanged', {'text': 'Go'});
    await native.send('searchSubmitted', {'text': 'Explore'});
    await native.send('accessoryTap');
    await native.send('accessoryAction', {'id': 'next'});
    expect(active, [true]);
    expect(controller.searchActive.value, isTrue);
    expect(texts, ['Go']);
    expect(submitted, ['Explore']);
    expect(accessoryTaps, 1);
    expect(actions, ['next']);

    await controller.setSearchText('Text');
    expect(native.calls.last.method, 'search');
    expect(native.calls.last.arguments, {'action': 'setText', 'text': 'Text'});
  });

  test('isNativeSupported follows the override', () {
    debugUseNativeTabBar = false;
    expect(UIKitTabBar.isNativeSupported, isFalse);
    debugUseNativeTabBar = true;
    expect(UIKitTabBar.isNativeSupported, isTrue);
    debugUseNativeTabBar = null;
    // Widget tests run as Android by default: fallback.
    expect(UIKitTabBar.isNativeSupported, isFalse);
  });
}
