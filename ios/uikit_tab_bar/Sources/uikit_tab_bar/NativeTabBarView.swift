import Flutter
import UIKit

/// Root view handed to Flutter. Reports when it enters a window and when
/// it lays out.
final class HostView: UIView {
  var onWindow: ((UIWindow?) -> Void)?
  var onLayout: (() -> Void)?
  var onTouch: (() -> Void)?

  // A tap on the minimized bar expands it inside UIKit, without a callback.
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    if event?.type == .touches { onTouch?() }
    return super.hitTest(point, with: event)
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    onWindow?(window)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    onLayout?()
  }

  /// Also fires when the vertical bar comes or goes without a resize.
  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    onLayout?()
  }

  var nearestViewController: UIViewController? {
    var responder: UIResponder? = superview
    while let r = responder {
      if let vc = r as? UIViewController { return vc }
      responder = r.next
    }
    return nil
  }
}

// SDK guards: `#available` only checks the OS at runtime; building with an
// SDK that doesn't declare an API fails at compile time. APIs newer than the
// iOS 26.0 SDK are therefore also wrapped in `#if compiler(...)`, using the
// Swift version Apple ships with the first Xcode carrying that SDK (Xcode
// release notes): Swift 6.2.1 = Xcode 26.1.1 = iOS 26.1 SDK (`UITab.selectedImage`),
// Swift 6.4 = Xcode 27 = iOS 27 SDK (prominent tab, `performBatchUpdates`).
// With an older Xcode these features are simply left out.

/// A `UITabBarController` inside a Flutter platform view. Its tab content
/// controllers are transparent placeholders; the content is Flutter,
/// rendered behind the platform view.
@available(iOS 26.0, *)
final class NativeTabBarView: NSObject, FlutterPlatformView, UITabBarControllerDelegate {
  private let host: HostView
  private let channel: FlutterMethodChannel
  private let controller = UITabBarController()
  private let images = ImageStore()
  private let panForwarder = PanForwarder()
  /// Stand-in for the selected tab's Flutter scrollable (see
  /// `PlaceholderViewController`).
  private let proxy = ProxyScrollView()
  private var state: BarState?
  /// Native tabs by Dart id; reused so each keeps its content controller.
  private var tabs: [String: UITab] = [:]
  private var accessoryView: AccessoryContentView?
  private var lastGeometry: [String: AnyHashable] = [:]
  private var displayLink: CADisplayLink?
  private var pollUntil: CFTimeInterval = 0
  private var searchActive = false
  /// Since when the vertical bar is shown without its column of tabs, and
  /// whether UIKit was already asked to rebuild it (see `rebuildColumn`).
  /// Content controllers of the tabs created so far; each carries the
  /// toolbar items on its navigation item (see `applyToolbar`).
  private let contents = NSHashTable<UIViewController>.weakObjects()
  /// Whether the toolbar items are shown: only in the vertical bar.
  private var toolbarShown = false
  private var columnMissingSince: CFTimeInterval?
  private var columnRebuilt = false

  init(frame: CGRect, channel: FlutterMethodChannel, args: [String: Any]) {
    host = HostView(frame: frame)
    self.channel = channel
    super.init()
    host.backgroundColor = .clear
    controller.delegate = self
    controller.view.backgroundColor = .clear
    controller.view.frame = host.bounds
    controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    if UIDevice.current.userInterfaceIdiom == .pad {
      // Regular width moves the bar to the top of the controller's view,
      // i.e. the top of our bottom strip. Keep the phone-style bottom bar.
      controller.traitOverrides.horizontalSizeClass = .compact
    }
    host.addSubview(controller.view)
    proxy.onReachedTop = { [weak self] in self?.expandIfMinimized() }
    host.onWindow = { [weak self] window in self?.windowChanged(window) }
    host.onLayout = { [weak self] in self?.pokeGeometry() }
    host.onTouch = { [weak self] in self?.keepPollingGeometry() }
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    images.add(args["images"] as? [String: Any] ?? [:])
    apply(BarState(args["state"] as? [String: Any] ?? [:]), animated: false)
  }

  deinit {
    displayLink?.invalidate()
    panForwarder.restore()
  }

  func view() -> UIView { host }

  // MARK: Containment

  private func windowChanged(_ window: UIWindow?) {
    if window != nil {
      if controller.parent == nil, let parent = host.nearestViewController {
        parent.addChild(controller)
        controller.didMove(toParent: parent)
      }
      applyVerticalBarBehavior()
      startDisplayLink()
    } else {
      if controller.parent != nil {
        VerticalBar.setDisabled(false, for: controller)
        controller.willMove(toParent: nil)
        controller.removeFromParent()
      }
      displayLink?.invalidate()
      displayLink = nil
    }
    updatePanForwarding()
    pokeGeometry()
  }

  // MARK: Dart -> native

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "update":
      images.add(args["images"] as? [String: Any] ?? [:])
      apply(BarState(args["state"] as? [String: Any] ?? [:]), animated: args["animated"] as? Bool ?? true)
      result(nil)
    case "scroll":
      // Only the selected tab's scrollable drives the shared proxy.
      if let id = args["tabId"] as? String, id == dartId(controller.selectedTab) {
        func d(_ k: String) -> Double { (args[k] as? NSNumber)?.doubleValue ?? 0 }
        proxy.mirror(pixels: d("pixels"), min: d("min"), max: d("max"))
        // Scrolling can minimize or expand the bar, again without a callback.
        keepPollingGeometry()
      }
      result(nil)
    case "search":
      handleSearch(args["action"] as? String, text: args["text"] as? String)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func apply(_ new: BarState, animated: Bool) {
    var diff = BarDiff.between(state, new)
    if let old = state, (old.toolbar == nil) != (new.toolbar == nil) {
      // The regular tabs only sit in a navigation controller while there
      // is a toolbar (see `makeTab`); build their controllers anew.
      for tab in old.tabs { tabs[tab.id] = nil }
      diff.structure = true
      diff.changedTabs = Set(new.tabs.map(\.id))
    }
    state = new
    let work = { [self] in
      if diff.structure || !diff.changedTabs.isEmpty || diff.search {
        applyTabs(new, diff: diff, animated: animated)
      }
      if diff.style {
        Appearance.apply(new.style, to: controller.tabBar)
        // The vertical bar ignores `UITabBar.tintColor` and inherits the
        // controller view's tint (measured on iOS 27.1).
        controller.view.tintColor = new.style.tint.map(UIColor.init(argb:))
      }
      if diff.brightness {
        controller.overrideUserInterfaceStyle = new.brightness == "dark" ? .dark : .light
      }
      if diff.rtl {
        let attribute: UISemanticContentAttribute = new.rtl ? .forceRightToLeft : .forceLeftToRight
        controller.view.semanticContentAttribute = attribute
        controller.tabBar.semanticContentAttribute = attribute
      }
      if diff.minimize { applyMinimizeBehavior(new.minimizeBehavior) }
      if tabsShouldHide != controller.isTabBarHidden {
        controller.setTabBarHidden(tabsShouldHide, animated: animated)
      }
      if diff.accessory { applyAccessory(new.accessory, animated: animated) }
      if diff.toolbar || diff.hidden {
        // Same batch as the tabs: no frame with both or neither.
        if new.hidden || new.toolbar == nil { toolbarShown = false }
        refreshToolbar()
      }
      if diff.verticalBar { applyVerticalBarBehavior() }
      #if compiler(>=6.4)  // iOS 27 SDK, see "SDK guards" at the top of this file
        if #available(iOS 27.0, *), diff.prominent || diff.structure {
          let id = new.prominentId.flatMap { tabs[$0]?.identifier }
          if id != controller.prominentTabIdentifier {
            controller.setProminentTabIdentifier(id, animated: animated)
          }
        }
      #endif
      // Always reconcile: the user may have selected natively and Dart
      // kept (vetoed) the previous selection.
      if new.rootIds.contains(new.selectedId), let tab = tabs[new.selectedId],
        controller.selectedTab !== tab
      {
        controller.selectedTab = tab
      }
    }
    #if compiler(>=6.4)  // iOS 27 SDK, see "SDK guards" at the top of this file
      if #available(iOS 27.0, *), animated, !diff.isEmpty {
        controller.performBatchUpdates(work)
      } else {
        work()
      }
    #else
      work()
    #endif
    updatePanForwarding()
    pokeGeometry()
  }

  private func applyTabs(_ s: BarState, diff: BarDiff, animated: Bool) {
    for spec in s.tabs {
      let tab = tabs[spec.id] ?? makeTab(spec.id)
      tabs[spec.id] = tab
      if diff.changedTabs.contains(spec.id) || diff.structure { configure(tab, spec) }
    }
    if let search = s.search {
      let tab = (tabs[search.id] as? UISearchTab) ?? makeSearchTab()
      tabs[search.id] = tab
      tab.automaticallyActivatesSearch = search.automaticallyActivatesSearch
      if let title = search.title { tab.title = title }
      (tab.viewController as? UINavigationController)
        .flatMap { $0.viewControllers.first as? SearchPlaceholderViewController }?
        .searchController.searchBar.placeholder = search.placeholder
    }
    let ids = s.rootIds
    // Keep hidden tabs' objects (and thus their state) for when they return.
    let known = Set(s.tabs.map(\.id) + (s.search.map { [$0.id] } ?? []))
    for id in tabs.keys where !known.contains(id) { tabs[id] = nil }
    // Without any tab the controller keeps the previous ones and the bar is
    // hidden instead (see `tabsShouldHide`): an empty set leaves a stub of
    // glass behind, and the tabs do not recover from it (iOS 27.2).
    if diff.structure, !ids.isEmpty {
      controller.setTabs(ids.compactMap { tabs[$0] }, animated: animated)
    }
  }

  /// Whether the tabs are not to be shown: `UITabBarController` hides its
  /// bar, and in the vertical bar the column keeps the toolbar.
  private var tabsShouldHide: Bool {
    guard let state else { return false }
    if state.hidden || state.rootIds.isEmpty { return true }
    switch state.tabsVisibility {
    case "hidden": return true
    case "hiddenInVerticalBar": return VerticalBar.edge(of: controller.traitCollection) != .none
    default: return false
    }
  }

  private func makeTab(_ id: String) -> UITab {
    UITab(title: "", image: nil, identifier: id) { [weak self] _ in
      guard let self else { return UIViewController() }
      let vc = PlaceholderViewController(proxy: self.proxy)
      vc.onAppear = { [weak self] in self?.updatePanForwarding() }
      self.contents.add(vc)
      // The vertical bar only takes buttons from system containers: they
      // have to be bar button items on the navigation item of a
      // navigation controller below the tab bar controller. Without a
      // toolbar the tab keeps its plain controller.
      guard self.state?.toolbar != nil else { return vc }
      let nav = UINavigationController(rootViewController: vc)
      nav.view.backgroundColor = .clear
      self.applyToolbar(to: vc)
      return nav
    }
  }

  private func makeSearchTab() -> UISearchTab {
    UISearchTab { [weak self] _ in
      let vc = SearchPlaceholderViewController()
      vc.onText = { text in self?.send("searchChanged", ["text": text]) }
      vc.onSubmit = { text in self?.send("searchSubmitted", ["text": text]) }
      vc.onActive = { active in
        self?.searchActive = active
        self?.send("searchActive", ["active": active])
        self?.pokeGeometry()
      }
      vc.searchController.searchBar.placeholder = self?.state?.search?.placeholder
      let nav = UINavigationController(rootViewController: vc)
      nav.view.backgroundColor = .clear
      self?.contents.add(vc)
      self?.applyToolbar(to: vc)
      return nav
    }
  }

  private func configure(_ tab: UITab, _ spec: TabSpec) {
    tab.title = spec.title
    tab.image = images.image(spec.icon)
    #if compiler(>=6.2.1)  // iOS 26.1 SDK, see "SDK guards" at the top of this file
      if #available(iOS 26.1, *) {
        tab.selectedImage = images.image(spec.selectedIcon)
      }
    #endif
    tab.badgeValue = spec.badge
    tab.subtitle = spec.subtitle
    tab.isEnabled = spec.enabled
    tab.accessibilityIdentifier = spec.id
  }

  private var minimizeEnabled: Bool {
    switch state?.minimizeBehavior {
    case "onScrollDown", "onScrollUp": return true
    default: return false
    }
  }

  private func applyMinimizeBehavior(_ name: String) {
    controller.tabBarMinimizeBehavior =
      switch name {
      case "never": .never
      case "onScrollDown": .onScrollDown
      case "onScrollUp": .onScrollUp
      default: .automatic
      }
    proxy.minimizeEnabled = minimizeEnabled
  }

  private func applyAccessory(_ spec: AccessorySpec?, animated: Bool) {
    guard let spec else {
      if controller.bottomAccessory != nil { controller.setBottomAccessory(nil, animated: animated) }
      accessoryView = nil
      return
    }
    if let view = accessoryView {
      view.configure(spec, images: images)
      return
    }
    let view = AccessoryContentView()
    view.configure(spec, images: images)
    view.onTap = { [weak self] in self?.send("accessoryTap", nil) }
    view.onAction = { [weak self] id in self?.send("accessoryAction", ["id": id]) }
    view.onEnvironment = { [weak self] _ in self?.pokeGeometry() }
    accessoryView = view
    controller.setBottomAccessory(UITabAccessory(contentView: view), animated: animated)
  }

  // MARK: Toolbar (vertical bar)

  private func refreshToolbar() {
    for vc in contents.allObjects { applyToolbar(to: vc) }
  }

  /// Puts the toolbar on the navigation item of a tab's content controller,
  /// or takes it away while the bar is horizontal: there the items would
  /// show up in a navigation bar at the top of the platform view. A regular
  /// tab's navigation bar is hidden then; UIKit only moves the items of a
  /// visible bar into the column.
  private func applyToolbar(to vc: UIViewController) {
    let spec = toolbarShown ? state?.toolbar : nil
    let item = vc.navigationItem
    item.leadingItemGroups =
      spec.map { $0.navigation.isEmpty ? [] : [group($0.navigation)] } ?? []
    item.trailingItemGroups = spec?.groups.filter { !$0.isEmpty }.map(group) ?? []
    item.additionalOverflowItems = spec.flatMap { overflowMenu($0.menu) }
    // UINavigationItem.verticalBarCompressionBehavior (iOS 27.1 SDK, used
    // dynamically like the rest of the vertical bar, see `VerticalBar`):
    // 0 = automatic, 1 = prefersBarItems, 2 = prefersTabBar.
    if item.responds(to: NSSelectorFromString("setVerticalBarCompressionBehavior:")) {
      let value =
        switch spec?.compression {
        case "prefersToolbar": 1
        case "prefersTabBar": 2
        default: 0
        }
      item.setValue(value, forKey: "verticalBarCompressionBehavior")
    }
    if !(vc is SearchPlaceholderViewController), let nav = vc.navigationController,
      nav.isNavigationBarHidden != (spec == nil)
    {
      nav.setNavigationBarHidden(spec == nil, animated: false)
    }
  }

  private func group(_ specs: [ToolbarItemSpec]) -> UIBarButtonItemGroup {
    UIBarButtonItemGroup.fixedGroup(items: specs.map(barButtonItem))
  }

  private func barButtonItem(_ spec: ToolbarItemSpec) -> UIBarButtonItem {
    let id = spec.id
    let action = UIAction(title: spec.label, image: images.image(spec.icon)) { [weak self] _ in
      self?.send("toolbarPressed", ["id": id])
    }
    let item = UIBarButtonItem(primaryAction: action)
    // With an image the bar shows the icon; the title is for the overflow
    // menu and VoiceOver.
    item.title = spec.label
    item.accessibilityLabel = spec.label
    item.accessibilityIdentifier = id
    item.isEnabled = spec.enabled
    if spec.prominent { item.style = .prominent }
    if let badge = spec.badge {
      item.badge = badge.isEmpty ? .indicator() : .string(badge)
    }
    #if compiler(>=6.4)  // iOS 27 SDK, see "SDK guards" at the top of this file
      if #available(iOS 27.0, *) {
        item.visibilityPriority =
          switch spec.priority {
          case "low": .low
          case "high": .high
          default: .standard
          }
      }
    #endif
    return item
  }

  private func overflowMenu(_ specs: [ToolbarMenuItemSpec]) -> UIDeferredMenuElement? {
    guard !specs.isEmpty else { return nil }
    return UIDeferredMenuElement.uncached { [weak self] completion in
      completion(
        specs.map { spec in
          var attributes: UIMenuElement.Attributes = []
          if spec.destructive { attributes.insert(.destructive) }
          if !spec.enabled { attributes.insert(.disabled) }
          let id = spec.id
          return UIAction(
            title: spec.label, image: self?.images.image(spec.icon), attributes: attributes
          ) { _ in self?.send("toolbarPressed", ["id": id]) }
        })
    }
  }

  private func handleSearch(_ action: String?, text: String?) {
    guard let id = state?.search?.id, let tab = tabs[id] else { return }
    let search = (tab.viewController as? UINavigationController)?.viewControllers.first
      as? SearchPlaceholderViewController
    switch action {
    case "activate":
      controller.selectedTab = tab
      DispatchQueue.main.async { search?.searchController.isActive = true }
    case "dismiss":
      search?.searchController.isActive = false
    case "setText":
      search?.setText(text ?? "")
    default:
      break
    }
  }

  /// Opting out goes to the root of the presentation (see `VerticalBar`).
  private func applyVerticalBarBehavior() {
    guard controller.parent != nil else { return }
    VerticalBar.setDisabled(state?.verticalBar == "disabled", for: controller)
  }

  /// Re-applying the behavior makes UIKit show the full bar again.
  private func expandIfMinimized() {
    guard lastGeometry["minimized"] as? Bool == true, state?.minimizeBehavior == "onScrollDown"
    else { return }
    let behavior = controller.tabBarMinimizeBehavior
    controller.tabBarMinimizeBehavior = .never
    controller.tabBarMinimizeBehavior = behavior
    pokeGeometry()
  }

  private func updatePanForwarding() {
    let content = controller.selectedTab?.viewController
    let onRegularTab =
      ((content as? UINavigationController)?.viewControllers.first ?? content)
      is PlaceholderViewController
    let target = host.window == nil ? nil : controller.parent?.view
    panForwarder.forward(minimizeEnabled && onRegularTab ? proxy : nil, to: target)
  }

  private func send(_ method: String, _ args: Any?) {
    channel.invokeMethod(method, arguments: args)
  }

  // MARK: Delegate

  private func dartId(_ tab: UITab?) -> String? {
    guard let tab else { return nil }
    return tabs.first { $0.value === tab }?.key
  }

  func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
    if tab === tabBarController.selectedTab, !(tab is UISearchTab) {
      if let id = dartId(tab) { send("reselected", ["id": id]) }
      return false
    }
    return true
  }

  func tabBarController(
    _ tabBarController: UITabBarController, didSelectTab selectedTab: UITab, previousTab: UITab?
  ) {
    if let id = dartId(selectedTab), id != state?.selectedId { send("selected", ["id": id]) }
    updatePanForwarding()
    pokeGeometry()
  }

  // MARK: Geometry

  /// Layout changes animate without callbacks we can hook (minimize, hide,
  /// accessory), so poll at display rate for a moment after any trigger.
  private func pokeGeometry() {
    keepPollingGeometry()
    reportGeometry()
  }

  /// Polls without measuring right away, for triggers that fire several
  /// times a frame (scroll updates, hit tests) before the layout changes.
  private func keepPollingGeometry() {
    pollUntil = CACurrentMediaTime() + 1.0
    displayLink?.isPaused = false
  }

  private func startDisplayLink() {
    guard displayLink == nil else { return }
    let link = CADisplayLink(target: DisplayLinkTarget(self), selector: #selector(DisplayLinkTarget.tick))
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  fileprivate func tick() {
    reportGeometry()
    if CACurrentMediaTime() > pollUntil { displayLink?.isPaused = true }
  }

  private func reportGeometry() {
    // Only while attached: before that, conversions use window coordinates.
    let bar = controller.tabBar
    guard host.window != nil, controller.parent != nil, host.bounds.width > 0,
      host.bounds.height > 0, bar.bounds.width > 0
    else { return }
    // With a vertical bar UIKit lays the tabs out in a column over the full
    // height of the controller's view. Dart grows the host to the full
    // screen once it learns the edge; until then the column would be
    // squeezed into the bottom strip, so the controller stays invisible.
    let edge = VerticalBar.edge(of: controller.traitCollection)
    let vertical = edge != .none
    let screenHeight = controller.parent?.view.bounds.height ?? host.bounds.height
    let squeezed = vertical && host.bounds.height < screenHeight * 0.9
    controller.view.alpha = squeezed ? 0 : 1
    var hitRects: [[Double]] = []
    var barRect: [Double] = []
    var glass: [CGRect] = []
    var toolbarRect: [Double] = []
    // The toolbar only exists in the vertical bar. Changing the navigation
    // items lays out again, so not from inside this pass.
    let showToolbar = vertical && !squeezed && state?.toolbar != nil && state?.hidden != true
    // `hiddenInVerticalBar` follows the bar as it turns.
    let hideTabs = tabsShouldHide
    if showToolbar != toolbarShown || hideTabs != controller.isTabBarHidden {
      toolbarShown = showToolbar
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        if self.tabsShouldHide != self.controller.isTabBarHidden {
          self.controller.setTabBarHidden(self.tabsShouldHide, animated: false)
        }
        self.refreshToolbar()
        self.pokeGeometry()
      }
    }
    let barVisible = !controller.isTabBarHidden && !bar.isHidden && bar.alpha > 0.01 && !squeezed
    if vertical {
      if barVisible || toolbarShown {
        let column = columnGlass()
        // Without the tabs only the toolbar's glass counts: whatever else
        // UIKit leaves in the column must not take touches.
        glass = (barVisible ? column.tabs : []) + column.toolbar
        if let first = column.toolbar.first {
          toolbarRect = rectList(column.toolbar.dropFirst().reduce(first) { $0.union($1) })
        }
        rebuildColumn(ifMissing: glass.isEmpty)
      }
    } else if barVisible {
      glass = glassRects(in: bar)
    }
    hitRects += glass.map(rectList)
    if barVisible { barRect = rectList(bar.convert(bar.bounds, to: host)) }
    var accessoryRect: [Double] = []
    if let content = accessoryView, content.window != nil, !content.isHidden {
      let r = content.convert(content.bounds, to: host).insetBy(dx: -4, dy: -4)
      accessoryRect = rectList(r)
      hitRects.append(accessoryRect)
    }
    var searchRect: [Double] = []
    // At the top (active, or in the vertical layout also inactive), the
    // field shares the navigation bar with its close button.
    let searchAtTop = searchActive || vertical
    if !squeezed, let field = firstVisible(UISearchBar.self, in: controller.view) {
      searchRect = rectList(field.convert(field.bounds, to: host))
      hitRects.append(searchRect)
      if searchAtTop, let nav = searchNavigationBar, nav.window != nil, !nav.isHidden {
        hitRects.append(rectList(nav.convert(nav.bounds, to: host)))
      }
    }
    let widest = glass.map(\.width).max() ?? 0
    // The vertical bar never minimizes.
    let minimized = !vertical && barVisible && widest > 0 && widest < bar.bounds.width * 0.6
    let guide = controller.contentLayoutGuide.layoutFrame
    let geometry: [String: AnyHashable] = [
      "bar": barRect,
      "accessory": accessoryRect,
      "search": searchRect,
      "toolbar": toolbarRect,
      "hitRects": hitRects,
      "hidden": controller.isTabBarHidden && !toolbarShown,
      "tabsHidden": controller.isTabBarHidden,
      "minimized": minimized,
      "bottomInset": Double(max(0, host.bounds.maxY - guide.maxY)),
      "leftInset": Double(max(0, guide.minX - host.bounds.minX)),
      "rightInset": Double(max(0, host.bounds.maxX - guide.maxX)),
      "verticalEdge": edge.rawValue,
      // At the top of the (then full-height) host, see `searchAtTop`.
      "topInset": searchAtTop && !searchRect.isEmpty ? searchRect[1] + searchRect[3] : 0.0,
      "accessoryEnvironment": accessoryView?.environmentName ?? "none",
    ]
    if geometry != lastGeometry {
      lastGeometry = geometry
      send("geometry", geometry)
    }
  }

  /// On the inner display of iPhone Duo (iOS 27.2), UIKit switches to the
  /// vertical layout when the app starts unfolded, but does not build the
  /// column of tabs: the edge stays empty. Showing the bar again builds it.
  /// Done once per appearance of the vertical bar, and only after the
  /// column stayed away for a moment, since it normally arrives a few
  /// frames after the layout.
  private func rebuildColumn(ifMissing missing: Bool) {
    guard missing else {
      columnMissingSince = nil
      columnRebuilt = false
      return
    }
    guard !columnRebuilt else { return }
    let now = CACurrentMediaTime()
    guard let since = columnMissingSince else {
      columnMissingSince = now
      keepPollingGeometry()
      return
    }
    guard now - since > 0.25 else {
      keepPollingGeometry()
      return
    }
    columnRebuilt = true
    let hidden = controller.isTabBarHidden
    controller.setTabBarHidden(!hidden, animated: false)
    controller.setTabBarHidden(hidden, animated: false)
    keepPollingGeometry()
  }

  /// The floating glass capsules inside the (full-width) tab bar view.
  private func glassRects(in bar: UITabBar) -> [CGRect] {
    var out: [CGRect] = []
    func visit(_ v: UIView, depth: Int) {
      guard !v.isHidden, v.alpha > 0.01, depth < 5 else { return }
      if v is UIVisualEffectView || String(describing: type(of: v)).contains("Platter") {
        let r = v.convert(v.bounds, to: host)
        if r.width > 20, r.height > 20 {
          out.append(r)
          return
        }
      }
      v.subviews.forEach { visit($0, depth: depth + 1) }
    }
    visit(bar, depth: 0)
    // Before the first glass layout pass, fall back to the bar itself.
    return out.isEmpty ? [bar.convert(bar.bounds, to: host)] : out
  }

  /// The glass column of the vertical bar. UIKit hosts it in the tab bar
  /// controller's view, next to the content, not inside `UITabBar`. Empty
  /// while UIKit has not built the column: the tab bar's bounds are the
  /// whole strip at the edge, which would swallow touches with nothing
  /// drawn there.
  ///
  /// The toolbar's buttons sit in the same column, in glass groups of their
  /// own; a group counts as the tabs' if it contains tab bar views (or the
  /// accessory).
  private func columnGlass() -> (tabs: [CGRect], toolbar: [CGRect]) {
    let content = controller.selectedViewController?.view
    var tabs: [CGRect] = []
    var toolbar: [CGRect] = []
    func name(_ v: UIView) -> String { String(describing: type(of: v)) }
    func holdsTabs(_ v: UIView, depth: Int) -> Bool {
      if name(v).contains("TabBar") { return true }
      return depth < 8 && v.subviews.contains { holdsTabs($0, depth: depth + 1) }
    }
    func visit(_ v: UIView, depth: Int) {
      guard !v.isHidden, v.alpha > 0.01, depth < 16 else { return }
      if let content, content.isDescendant(of: v), v !== controller.view { return }
      let n = name(v)
      if v is UIVisualEffectView || n.contains("Platter") || n.contains("GlassInteractionView") {
        let r = v.convert(v.bounds, to: host)
        if r.width > 20, r.height > 20 {
          let other = !toolbarShown || accessoryView?.isDescendant(of: v) == true
          if other || holdsTabs(v, depth: 0) { tabs.append(r) } else { toolbar.append(r) }
          return
        }
      }
      v.subviews.forEach { visit($0, depth: depth + 1) }
    }
    controller.view.subviews.forEach { visit($0, depth: 0) }
    return (tabs, toolbar)
  }

  private var searchNavigationBar: UINavigationBar? {
    guard let id = state?.search?.id, let tab = tabs[id], controller.selectedTab === tab else { return nil }
    return (tab.viewController as? UINavigationController)?.navigationBar
  }

  private func firstVisible<T: UIView>(_ type: T.Type, in v: UIView) -> T? {
    guard !v.isHidden, v.alpha > 0.01 else { return nil }
    if let t = v as? T, t.window != nil, t.bounds.width > 0 { return t }
    for s in v.subviews {
      if let found = firstVisible(type, in: s) { return found }
    }
    return nil
  }

  private func rectList(_ r: CGRect) -> [Double] {
    [r.minX, r.minY, r.width, r.height].map { (Double($0) * 10).rounded() / 10 }
  }
}

/// Breaks the display link's retain cycle.
@available(iOS 26.0, *)
private final class DisplayLinkTarget: NSObject {
  weak var view: NativeTabBarView?
  init(_ view: NativeTabBarView) { self.view = view }
  @objc func tick() { view?.tick() }
}
