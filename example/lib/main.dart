import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uikit_tab_bar/uikit_tab_bar.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  ThemeMode themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'uikit_tab_bar',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(colorSchemeSeed: Colors.green),
      darkTheme: ThemeData(colorSchemeSeed: Colors.green, brightness: Brightness.dark),
      home: DemoHome(
        themeMode: themeMode,
        onThemeMode: (mode) => setState(() => themeMode = mode),
      ),
    );
  }
}

/// Every option of [UIKitTabBar], switchable at runtime in the "Optionen" tab.
class DemoOptions {
  bool hidden = false;
  bool accessory = true;
  bool prominent = false;
  bool search = true;
  bool autoSearch = false;
  UIKitTabBarMinimizeBehavior minimize = UIKitTabBarMinimizeBehavior.onScrollDown;
  bool tint = true;
  bool selectedColor = false;
  bool font = false;
  bool titleOffset = false;
  bool badgeColors = false;
  int badgeCount = 3;
  bool exploreDisabled = false;
  bool eventsHidden = false;
  bool subtitles = false;
  bool forceFallback = false;
}

class DemoHome extends StatefulWidget {
  const DemoHome({super.key, required this.themeMode, required this.onThemeMode});

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;

  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  static const tabIds = ['home', 'explore', 'events', 'options', 'search'];

  final options = DemoOptions();
  final controller = UIKitTabBarController();
  final scrollControllers = {for (final id in tabIds) id: ScrollController()};
  String selected = 'home';
  String searchText = '';
  String lastEvent = '–';

  @override
  void dispose() {
    controller.dispose();
    for (final c in scrollControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _event(String text) {
    debugPrint('[example] $text');
    setState(() => lastEvent = text);
  }

  void _update(VoidCallback change) {
    setState(change);
    debugUseNativeTabBar = options.forceFallback ? false : null;
  }

  List<UIKitTab> get _tabs => [
        UIKitTab(
          id: 'home',
          label: 'Home',
          icon: const UIKitTabIcon.symbol('house'),
          selectedIcon: const UIKitTabIcon.symbol('house.fill'),
          fallbackIcon: const Icon(CupertinoIcons.house),
          fallbackSelectedIcon: const Icon(CupertinoIcons.house_fill),
          subtitle: options.subtitles ? 'Start' : null,
        ),
        UIKitTab(
          id: 'explore',
          label: 'Entdecken',
          // An app asset; resolution-aware (1x/2x/3x).
          icon: const UIKitTabIcon.image(AssetImage('assets/icons/star.png')),
          enabled: !options.exploreDisabled,
          subtitle: options.subtitles ? 'Neu' : null,
        ),
        UIKitTab(
          id: 'events',
          label: 'Events',
          // A Flutter IconData, rendered to a template image.
          icon: const UIKitTabIcon.icon(Icons.event_outlined),
          selectedIcon: const UIKitTabIcon.icon(Icons.event),
          badge: options.badgeCount > 0 ? '${options.badgeCount}' : null,
          hidden: options.eventsHidden,
          subtitle: options.subtitles ? 'Termine' : null,
        ),
        const UIKitTab(
          id: 'options',
          label: 'Optionen',
          icon: UIKitTabIcon.symbol('slider.horizontal.3'),
          fallbackIcon: Icon(CupertinoIcons.slider_horizontal_3),
        ),
      ];

  UIKitTabBarStyle get _style => UIKitTabBarStyle(
        tintColor: options.tint ? Theme.of(context).colorScheme.primary : null,
        selectedColor: options.selectedColor ? Colors.deepOrange : null,
        titleFontAsset: options.font ? 'assets/fonts/Roboto-Bold.ttf' : null,
        titleFontSize: options.font ? 11 : null,
        titleOffset: options.titleOffset ? const Offset(0, -2) : null,
        badgeColor: options.badgeColors ? Colors.teal : null,
        badgeTextColor: options.badgeColors ? Colors.yellowAccent : null,
      );

  @override
  Widget build(BuildContext context) {
    final bar = UIKitTabBar(
      tabs: _tabs,
      selectedId: selected,
      onSelected: (id) {
        setState(() => selected = id);
        _event('selected $id');
      },
      onReselect: (id) {
        _event('reselected $id → nach oben');
        final c = scrollControllers[id]!;
        if (c.hasClients) {
          c.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
        }
      },
      searchTab: options.search
          ? UIKitSearchTab(
              label: 'Suche',
              placeholder: 'Stadt suchen',
              automaticallyActivatesSearch: options.autoSearch,
              onChanged: (text) => setState(() => searchText = text),
              onSubmitted: (text) => _event('search submitted "$text"'),
              onActiveChanged: (active) => _event('search active: $active'),
            )
          : null,
      prominentTabId: options.prominent ? 'events' : null,
      minimizeBehavior: options.minimize,
      hidden: options.hidden,
      accessory: options.accessory
          ? UIKitTabAccessory(
              title: 'Läuft gerade – Folge 7',
              subtitle: 'Podcast · noch 12 Min.',
              icon: const UIKitTabIcon.symbol('headphones'),
              actions: const [
                UIKitAccessoryAction(
                    id: 'pause', icon: UIKitTabIcon.symbol('pause.fill'), semanticLabel: 'Pause'),
                UIKitAccessoryAction(
                    id: 'next', icon: UIKitTabIcon.symbol('forward.fill'), semanticLabel: 'Weiter'),
              ],
              onTap: () => _event('accessory tapped'),
              onAction: (id) => _event('accessory action $id'),
            )
          : null,
      style: _style,
      controller: controller,
      onGeometryChanged: (g) => debugPrint('[example] $g'),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: UIKitTabScaffold(
        controller: controller,
        tabBar: bar,
        body: IndexedStack(
          index: tabIds.indexOf(selected).clamp(0, tabIds.length - 1),
          children: [
            _ListPage(title: 'Home', controller: scrollControllers['home']!),
            _ListPage(title: 'Entdecken', controller: scrollControllers['explore']!),
            _ListPage(title: 'Events', controller: scrollControllers['events']!),
            _OptionsPage(
              controller: scrollControllers['options']!,
              options: options,
              tabBarController: controller,
              themeMode: widget.themeMode,
              onThemeMode: widget.onThemeMode,
              lastEvent: lastEvent,
              onChanged: _update,
            ),
            _SearchPage(
              controller: scrollControllers['search']!,
              text: searchText,
              onFallbackChanged: (t) => setState(() => searchText = t),
              tabBarController: controller,
            ),
          ],
        ),
      ),
    );
  }
}

class _ListPage extends StatelessWidget {
  const _ListPage({required this.title, required this.controller});

  final String title;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.paddingOf(context);
    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.fromLTRB(16, media.top + 16, 16, media.bottom + 16),
      itemCount: 41,
      itemBuilder: (context, i) {
        if (i == 0) return Text(title, style: Theme.of(context).textTheme.headlineMedium);
        return Container(
          height: 72,
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [
              Colors.primaries[i % Colors.primaries.length],
              Colors.primaries[(i + 5) % Colors.primaries.length],
            ]),
          ),
          alignment: Alignment.center,
          child: Text('$title $i', style: const TextStyle(color: Colors.white, fontSize: 20)),
        );
      },
    );
  }
}

class _OptionsPage extends StatelessWidget {
  const _OptionsPage({
    required this.controller,
    required this.options,
    required this.tabBarController,
    required this.themeMode,
    required this.onThemeMode,
    required this.lastEvent,
    required this.onChanged,
  });

  final ScrollController controller;
  final DemoOptions options;
  final UIKitTabBarController tabBarController;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;
  final String lastEvent;
  final void Function(VoidCallback) onChanged;

  Widget _switch(String title, bool value, void Function(bool) set, {String? subtitle}) => SwitchListTile(
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        value: value,
        onChanged: (v) => onChanged(() => set(v)),
      );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.paddingOf(context);
    return ListView(
      controller: controller,
      padding: EdgeInsets.only(top: media.top, bottom: media.bottom + 16),
      children: [
        ListTile(
          title: Text('Optionen', style: Theme.of(context).textTheme.headlineMedium),
          subtitle: Text(UIKitTabBar.isNativeSupported ? 'Native UIKit-Bar (iOS 26+)' : 'Cupertino-Fallback'),
        ),
        ListTile(title: const Text('Letztes Ereignis'), subtitle: Text(lastEvent)),
        ValueListenableBuilder(
          valueListenable: tabBarController.geometry,
          builder: (context, g, _) => ListTile(
            title: const Text('Geometrie'),
            subtitle: Text(
              'bottomInset ${g.bottomInset.toStringAsFixed(1)} · minimiert ${g.minimized} · '
              'versteckt ${g.hidden} · Accessory ${g.accessoryEnvironment.name}',
            ),
          ),
        ),
        const _Header('Bar'),
        _switch('Ausblenden', options.hidden, (v) => options.hidden = v),
        ListTile(
          title: const Text('Minimieren'),
          subtitle: SegmentedButton<UIKitTabBarMinimizeBehavior>(
            showSelectedIcon: false,
            segments: [
              for (final b in UIKitTabBarMinimizeBehavior.values)
                ButtonSegment(value: b, label: Text(b.name, style: const TextStyle(fontSize: 11))),
            ],
            selected: {options.minimize},
            onSelectionChanged: (s) => onChanged(() => options.minimize = s.first),
          ),
        ),
        _switch('Bottom Accessory', options.accessory, (v) => options.accessory = v),
        _switch('Events hervorheben', options.prominent, (v) => options.prominent = v,
            subtitle: 'prominentTabIdentifier, iOS 27+'),
        _switch('Such-Tab', options.search, (v) => options.search = v),
        _switch('Suche sofort aktivieren', options.autoSearch, (v) => options.autoSearch = v,
            subtitle: 'automaticallyActivatesSearch'),
        const _Header('Tabs'),
        ListTile(
          title: Text('Badge Events: ${options.badgeCount}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: () => onChanged(() => options.badgeCount = (options.badgeCount - 1).clamp(0, 99)),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => onChanged(() => options.badgeCount++),
            ),
          ]),
        ),
        _switch('Entdecken deaktiviert', options.exploreDisabled, (v) => options.exploreDisabled = v),
        _switch('Events versteckt', options.eventsHidden, (v) => options.eventsHidden = v),
        _switch('Untertitel', options.subtitles, (v) => options.subtitles = v),
        const _Header('Stil'),
        _switch('Tint aus dem Theme', options.tint, (v) => options.tint = v),
        _switch('Auswahlfarbe orange', options.selectedColor, (v) => options.selectedColor = v),
        _switch('App-Font (Roboto Bold)', options.font, (v) => options.font = v),
        _switch('Titel nach oben', options.titleOffset, (v) => options.titleOffset = v),
        _switch('Badge-Farben', options.badgeColors, (v) => options.badgeColors = v),
        ListTile(
          title: const Text('Erscheinungsbild'),
          subtitle: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Hell')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dunkel')),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) => onThemeMode(s.first),
          ),
        ),
        const _Header('Plattform'),
        _switch('Fallback erzwingen', options.forceFallback, (v) => options.forceFallback = v,
            subtitle: 'CupertinoTabBar wie auf iOS < 26 und Android'),
        const _Header('Suche (Controller)'),
        ListTile(title: const Text('Suche aktivieren'), onTap: tabBarController.activateSearch),
        ListTile(
          title: const Text('Suchtext auf „Berlin" setzen'),
          onTap: () => tabBarController.setSearchText('Berlin'),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
        child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelMedium),
      );
}

class _SearchPage extends StatelessWidget {
  const _SearchPage({
    required this.controller,
    required this.text,
    required this.onFallbackChanged,
    required this.tabBarController,
  });

  final ScrollController controller;
  final String text;
  final ValueChanged<String> onFallbackChanged;
  final UIKitTabBarController tabBarController;

  static const cities = [
    'Berlin',
    'Hamburg',
    'München',
    'Köln',
    'Frankfurt',
    'Stuttgart',
    'Düsseldorf',
    'Leipzig',
  ];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.paddingOf(context);
    final hits = cities.where((c) => c.toLowerCase().contains(text.toLowerCase())).toList();
    return ValueListenableBuilder(
      valueListenable: tabBarController.geometry,
      builder: (context, geometry, _) => ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(16, media.top + 16, 16, media.bottom + 16),
        children: [
          Text('Suche', style: Theme.of(context).textTheme.headlineMedium),
          // The native search field lives in the bar; the fallback needs one.
          if (!geometry.isNative)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CupertinoSearchTextField(onChanged: onFallbackChanged),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(text.isEmpty ? 'Alle Städte' : '${hits.length} Treffer für „$text"'),
          ),
          for (final city in hits) ListTile(leading: const Icon(Icons.location_city), title: Text(city)),
        ],
      ),
    );
  }
}
