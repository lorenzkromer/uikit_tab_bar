import Flutter
import UIKit

/// Root view handed to Flutter. Reports when it enters a window and when
/// it lays out.
final class HostView: UIView {
  var onWindow: ((UIWindow?) -> Void)?
  var onLayout: (() -> Void)?

  override func didMoveToWindow() {
    super.didMoveToWindow()
    onWindow?(window)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
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
      startDisplayLink()
    } else {
      if controller.parent != nil {
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
    let diff = BarDiff.between(state, new)
    state = new
    let work = { [self] in
      if diff.structure || !diff.changedTabs.isEmpty || diff.search {
        applyTabs(new, diff: diff, animated: animated)
      }
      if diff.style { Appearance.apply(new.style, to: controller.tabBar) }
      if diff.brightness {
        controller.overrideUserInterfaceStyle = new.brightness == "dark" ? .dark : .light
      }
      if diff.rtl {
        let attribute: UISemanticContentAttribute = new.rtl ? .forceRightToLeft : .forceLeftToRight
        controller.view.semanticContentAttribute = attribute
        controller.tabBar.semanticContentAttribute = attribute
      }
      if diff.minimize { applyMinimizeBehavior(new.minimizeBehavior) }
      if diff.hidden, new.hidden != controller.isTabBarHidden {
        controller.setTabBarHidden(new.hidden, animated: animated)
      }
      if diff.accessory { applyAccessory(new.accessory, animated: animated) }
      if #available(iOS 27.0, *), diff.prominent || diff.structure {
        let id = new.prominentId.flatMap { tabs[$0]?.identifier }
        if id != controller.prominentTabIdentifier {
          controller.setProminentTabIdentifier(id, animated: animated)
        }
      }
      // Always reconcile: the user may have selected natively and Dart
      // kept (vetoed) the previous selection.
      if new.rootIds.contains(new.selectedId), let tab = tabs[new.selectedId],
        controller.selectedTab !== tab
      {
        controller.selectedTab = tab
      }
    }
    if #available(iOS 27.0, *), animated, !diff.isEmpty {
      controller.performBatchUpdates(work)
    } else {
      work()
    }
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
    if diff.structure {
      controller.setTabs(ids.compactMap { tabs[$0] }, animated: animated)
    }
  }

  private func makeTab(_ id: String) -> UITab {
    UITab(title: "", image: nil, identifier: id) { [weak self] _ in
      guard let self else { return UIViewController() }
      let vc = PlaceholderViewController(proxy: self.proxy)
      vc.onAppear = { [weak self] in self?.updatePanForwarding() }
      return vc
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
      return nav
    }
  }

  private func configure(_ tab: UITab, _ spec: TabSpec) {
    tab.title = spec.title
    tab.image = images.image(spec.icon)
    if #available(iOS 26.1, *) {
      tab.selectedImage = images.image(spec.selectedIcon)
    }
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
    let onRegularTab = controller.selectedTab?.viewController is PlaceholderViewController
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
    pollUntil = CACurrentMediaTime() + 1.0
    displayLink?.isPaused = false
    reportGeometry()
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
    var hitRects: [[Double]] = []
    var barRect: [Double] = []
    var glass: [CGRect] = []
    let barVisible = !controller.isTabBarHidden && !bar.isHidden && bar.alpha > 0.01
    if barVisible {
      glass = glassRects(in: bar)
      hitRects += glass.map(rectList)
      barRect = rectList(bar.convert(bar.bounds, to: host))
    }
    var accessoryRect: [Double] = []
    if let content = accessoryView, content.window != nil, !content.isHidden {
      let r = content.convert(content.bounds, to: host).insetBy(dx: -4, dy: -4)
      accessoryRect = rectList(r)
      hitRects.append(accessoryRect)
    }
    var searchRect: [Double] = []
    if let field = firstVisible(UISearchBar.self, in: controller.view) {
      searchRect = rectList(field.convert(field.bounds, to: host))
      hitRects.append(searchRect)
    }
    let widest = glass.map(\.width).max() ?? 0
    let minimized = barVisible && widest > 0 && widest < bar.bounds.width * 0.6
    let guide = controller.contentLayoutGuide.layoutFrame
    let geometry: [String: AnyHashable] = [
      "bar": barRect,
      "accessory": accessoryRect,
      "search": searchRect,
      "hitRects": hitRects,
      "hidden": controller.isTabBarHidden,
      "minimized": minimized,
      "bottomInset": Double(max(0, host.bounds.maxY - guide.maxY)),
      // Active, the field sits at the top of the (then full-height) host.
      "topInset": searchActive && !searchRect.isEmpty ? searchRect[1] + searchRect[3] : 0.0,
      "accessoryEnvironment": accessoryView?.environmentName ?? "none",
    ]
    if geometry != lastGeometry {
      lastGeometry = geometry
      send("geometry", geometry)
    }
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
