import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uikit_tab_bar/uikit_tab_bar.dart';

Widget _app(Widget child) => CupertinoApp(home: CupertinoPageScaffold(child: Align(alignment: Alignment.bottomCenter, child: child)));

const _tabs = [
  UIKitTab(
    id: 'home',
    label: 'Home',
    icon: UIKitTabIcon.symbol('house'),
    fallbackIcon: Icon(CupertinoIcons.house),
    badge: '3',
  ),
  UIKitTab(id: 'explore', label: 'Explore', icon: UIKitTabIcon.icon(CupertinoIcons.star)),
  UIKitTab(id: 'off', label: 'Off', icon: UIKitTabIcon.icon(CupertinoIcons.xmark), enabled: false),
  UIKitTab(id: 'gone', label: 'Gone', icon: UIKitTabIcon.icon(CupertinoIcons.trash), hidden: true),
];

void main() {
  setUp(() => debugUseNativeTabBar = false);
  tearDown(() => debugUseNativeTabBar = null);

  testWidgets('builds a CupertinoTabBar from the same tabs', (tester) async {
    await tester.pumpWidget(_app(UIKitTabBar(
      tabs: _tabs,
      selectedId: 'explore',
      onSelected: (_) {},
      searchTab: const UIKitSearchTab(label: 'Suche'),
    )));
    final bar = tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar));
    expect(bar.items.map((i) => i.label), ['Home', 'Explore', 'Off', 'Suche']);
    expect(bar.currentIndex, 1);
    expect(find.text('3'), findsOneWidget, reason: 'badge');
    expect(find.text('Gone'), findsNothing);
  });

  testWidgets('tap selects, tap on the current tab reselects, disabled ignores', (tester) async {
    final selected = <String>[];
    final reselected = <String>[];
    await tester.pumpWidget(_app(UIKitTabBar(
      tabs: _tabs,
      selectedId: 'home',
      onSelected: selected.add,
      onReselect: reselected.add,
    )));
    await tester.tap(find.text('Explore'));
    await tester.tap(find.text('Home'));
    await tester.tap(find.text('Off'));
    expect(selected, ['explore']);
    expect(reselected, ['home']);
  });

  testWidgets('uses the tint and hides with the bar', (tester) async {
    var hidden = false;
    late StateSetter set;
    await tester.pumpWidget(_app(StatefulBuilder(builder: (context, setState) {
      set = setState;
      return UIKitTabBar(
        tabs: _tabs,
        selectedId: 'home',
        onSelected: (_) {},
        hidden: hidden,
        style: const UIKitTabBarStyle(tintColor: Color(0xFF00AA00)),
      );
    })));
    expect(tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar)).activeColor, const Color(0xFF00AA00));
    set(() => hidden = true);
    await tester.pump();
    expect(find.byType(CupertinoTabBar), findsNothing);
  });

  testWidgets('reports a non-native geometry', (tester) async {
    final controller = UIKitTabBarController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(UIKitTabBar(tabs: _tabs, selectedId: 'home', onSelected: (_) {}, controller: controller)));
    await tester.pump();
    final g = controller.geometry.value;
    expect(g.isNative, isFalse);
    expect(g.bottomInset, 50, reason: 'CupertinoTabBar height without safe area in tests');
  });

  testWidgets('badgeOffset moves the badge, directionally', (tester) async {
    Future<Offset> badgeAt(Offset? offset, TextDirection dir) async {
      await tester.pumpWidget(Directionality(
        textDirection: dir,
        child: _app(UIKitTabBar(
          tabs: _tabs,
          selectedId: 'explore',
          onSelected: (_) {},
          style: UIKitTabBarStyle(badgeOffset: offset),
        )),
      ));
      return tester.getCenter(find.text('3'));
    }

    final ltr = await badgeAt(null, TextDirection.ltr);
    final ltrMoved = await badgeAt(const Offset(-8, 2), TextDirection.ltr);
    expect(ltrMoved.dx - ltr.dx, closeTo(-8, 0.01));
    expect(ltrMoved.dy - ltr.dy, closeTo(2, 0.01));
  });

  testWidgets('badge font size and weight', (tester) async {
    await tester.pumpWidget(_app(UIKitTabBar(
      tabs: _tabs,
      selectedId: 'explore',
      onSelected: (_) {},
      style: const UIKitTabBarStyle(badgeFontSize: 9, badgeFontWeight: FontWeight.w600),
    )));
    final style = tester.widget<Text>(find.text('3')).style!;
    expect(style.fontSize, 9);
    expect(style.fontWeight, FontWeight.w600);
  });

  testWidgets('an SF Symbol without fallbackIcon is an error', (tester) async {
    await tester.pumpWidget(_app(UIKitTabBar(
      tabs: const [
        UIKitTab(id: 'a', label: 'A', icon: UIKitTabIcon.symbol('house')),
        UIKitTab(id: 'b', label: 'B', icon: UIKitTabIcon.icon(CupertinoIcons.star)),
      ],
      selectedId: 'a',
      onSelected: (_) {},
    )));
    expect(tester.takeException(), isA<FlutterError>());
  });

  testWidgets('scaffold pads the body by the bar height', (tester) async {
    late EdgeInsets bodyPadding;
    await tester.pumpWidget(CupertinoApp(
      home: UIKitTabScaffold(
        tabBar: UIKitTabBar(tabs: _tabs, selectedId: 'home', onSelected: (_) {}),
        body: Builder(builder: (context) {
          bodyPadding = MediaQuery.paddingOf(context);
          return const SizedBox.expand();
        }),
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(bodyPadding.bottom, 50);
  });
}
