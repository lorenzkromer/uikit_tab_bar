import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uikit_tab_bar/src/protocol.dart';
import 'package:uikit_tab_bar/uikit_tab_bar.dart';

const _home = UIKitTab(id: 'home', label: 'Home', icon: UIKitTabIcon.symbol('house'));

RenderedIcon? _noImages(UIKitTabIcon icon) => null;

void main() {
  group('encodeState', () {
    test('encodes tabs, selection and options', () {
      final encoded = encodeState(
        const TabBarState(
          tabs: [
            UIKitTab(
              id: 'home',
              label: 'Home',
              icon: UIKitTabIcon.symbol('house'),
              selectedIcon: UIKitTabIcon.symbol('house.fill'),
              badge: '3',
              enabled: false,
            ),
          ],
          selectedId: 'home',
          searchTab: UIKitSearchTab(placeholder: 'Find', automaticallyActivatesSearch: true),
          prominentTabId: 'home',
          minimizeBehavior: UIKitTabBarMinimizeBehavior.onScrollDown,
          hidden: true,
          brightness: Brightness.dark,
          rtl: true,
        ),
        _noImages,
      );
      expect(encoded['tabs'], [
        {
          'id': 'home',
          'title': 'Home',
          'icon': {'symbol': 'house'},
          'selectedIcon': {'symbol': 'house.fill'},
          'badge': '3',
          'subtitle': null,
          'enabled': false,
          'hidden': false,
        },
      ]);
      expect(encoded['search'], {
        'id': 'search',
        'title': null,
        'placeholder': 'Find',
        'automaticallyActivatesSearch': true,
      });
      expect(encoded['selectedId'], 'home');
      expect(encoded['prominentId'], 'home');
      expect(encoded['minimizeBehavior'], 'onScrollDown');
      expect(encoded['hidden'], true);
      expect(encoded['brightness'], 'dark');
      expect(encoded['rtl'], true);
      expect(encoded['accessory'], isNull);
    });

    test('encodes style colors as ARGB and fonts', () {
      final encoded = encodeState(
        const TabBarState(
          tabs: [_home],
          selectedId: 'home',
          style: UIKitTabBarStyle(
            tintColor: Color(0xFF112233),
            selectedColor: Color(0x80445566),
            titleFontAsset: 'assets/f.ttf',
            titleFontSize: 11,
            titleFontWeight: FontWeight.w600,
            titleOffset: Offset(0, -2),
            badgeColor: Color(0xFF00FF00),
          ),
        ),
        _noImages,
      );
      expect(encoded['style'], {
        'tint': 0xFF112233,
        'selected': 0x80445566,
        'fontAsset': 'assets/f.ttf',
        'fontSize': 11.0,
        'fontWeight': 600,
        'titleOffset': [0.0, -2.0],
        'badge': 0xFF00FF00,
        'badgeText': null,
      });
    });

    test('image icons refer to rendered keys, pending ones are null', () {
      const rendered = UIKitTabIcon.icon(IconData(0xe000));
      const pending = UIKitTabIcon.icon(IconData(0xe001));
      final encoded = encodeState(
        const TabBarState(
          tabs: [
            UIKitTab(id: 'a', label: 'A', icon: rendered),
            UIKitTab(id: 'b', label: 'B', icon: pending),
          ],
          selectedId: 'a',
        ),
        (icon) => icon == rendered
            ? RenderedIcon(key: 'i7', png: Uint8List(1), scale: 3)
            : null,
      );
      final tabs = encoded['tabs']! as List;
      expect((tabs[0] as Map)['icon'], {'image': 'i7', 'scale': 3.0});
      expect((tabs[1] as Map)['icon'], isNull);
      expect(referencedImageKeys(encoded), {'i7'});
    });

    test('encodes the accessory', () {
      final encoded = encodeState(
        TabBarState(
          tabs: const [_home],
          selectedId: 'home',
          accessory: UIKitTabAccessory(
            title: 'Now',
            subtitle: 'Sub',
            icon: const UIKitTabIcon.symbol('music.note'),
            actions: const [
              UIKitAccessoryAction(id: 'play', icon: UIKitTabIcon.symbol('play'), semanticLabel: 'Play'),
            ],
            onTap: () {},
          ),
        ),
        _noImages,
      );
      expect(encoded['accessory'], {
        'title': 'Now',
        'subtitle': 'Sub',
        'icon': {'symbol': 'music.note'},
        'actions': [
          {
            'id': 'play',
            'icon': {'symbol': 'play'},
            'label': 'Play',
          },
        ],
      });
    });

    test('rejects more than five tabs including search', () {
      final tabs = [
        for (var i = 0; i < 5; i++) UIKitTab(id: '$i', label: '$i', icon: const UIKitTabIcon.symbol('x')),
      ];
      expect(() => encodeState(TabBarState(tabs: tabs, selectedId: '0'), _noImages), returnsNormally);
      expect(
        () => encodeState(
          TabBarState(tabs: tabs, selectedId: '0', searchTab: const UIKitSearchTab()),
          _noImages,
        ),
        throwsAssertionError,
      );
    });

    test('rejects duplicate ids', () {
      expect(
        () => encodeState(const TabBarState(tabs: [_home, _home], selectedId: 'home'), _noImages),
        throwsAssertionError,
      );
      expect(
        () => encodeState(
          const TabBarState(tabs: [_home], selectedId: 'home', searchTab: UIKitSearchTab(id: 'home')),
          _noImages,
        ),
        throwsAssertionError,
      );
    });
  });

  test('encodedEquals compares deeply', () {
    expect(
      encodedEquals({
        'a': [1, {'b': 2}],
      }, {
        'a': [1, {'b': 2}],
      }),
      isTrue,
    );
    expect(encodedEquals({'a': [1]}, {'a': [2]}), isFalse);
    expect(encodedEquals({'a': 1}, {'b': 1}), isFalse);
    expect(encodedEquals({'a': 1}, null), isFalse);
  });

  test('decodeGeometry', () {
    final g = decodeGeometry({
      'bottomInset': 139,
      'topInset': 112,
      'bar': [0, 117, 420, 83],
      'accessory': <Object?>[],
      'search': [20, 10, 380, 44],
      'hitRects': [
        [21, 117, 378, 62],
        [17.5, 57, 386, 56],
      ],
      'minimized': true,
      'hidden': false,
      'accessoryEnvironment': 'inline',
    });
    expect(g.isNative, isTrue);
    expect(g.bottomInset, 139);
    expect(g.topInset, 112);
    expect(g.barRect, const Rect.fromLTWH(0, 117, 420, 83));
    expect(g.accessoryRect, isNull);
    expect(g.searchFieldRect, const Rect.fromLTWH(20, 10, 380, 44));
    expect(g.hitRects, const [Rect.fromLTWH(21, 117, 378, 62), Rect.fromLTWH(17.5, 57, 386, 56)]);
    expect(g.minimized, isTrue);
    expect(g.accessoryEnvironment, UIKitTabAccessoryEnvironment.inline);
    expect(decodeGeometry({'accessoryEnvironment': 'bogus'}).accessoryEnvironment,
        UIKitTabAccessoryEnvironment.none);
  });
}
