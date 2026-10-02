import UIKit

/// A view that never claims touches for itself, only its subviews can.
final class PassthroughView: UIView {
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let hit = super.hitTest(point, with: event)
    return hit === self ? nil : hit
  }
}

/// Invisible stand-in for the Flutter scrollable of one tab.
///
/// UIKit only minimizes the tab bar for real pans of the observed content
/// scroll view; programmatic offsets are ignored. So the pan recognizer of
/// this view is moved onto the FlutterView (see `PanForwarder`): the user's
/// finger drives this view natively while Flutter scrolls its own content
/// from the same touches. Outside a drag it follows Flutter's position.
final class ProxyScrollView: UIScrollView, UIScrollViewDelegate {
  /// Whether the Flutter scrollable can scroll at all.
  private(set) var scrollable = false
  /// Set by the bar: pans only count while minimizing is enabled.
  var minimizeEnabled = false

  override init(frame: CGRect) {
    super.init(frame: frame)
    delegate = self
    contentInsetAdjustmentBehavior = .never
    showsVerticalScrollIndicator = false
    showsHorizontalScrollIndicator = false
    scrollsToTop = false  // keep the status-bar tap for Flutter
    // Flutter draws the overscroll; a bouncing proxy would make UIKit read
    // a pull at the top edge as scrolling and minimize the bar.
    bounces = false
    isUserInteractionEnabled = false  // touches arrive via the forwarded pan
    alpha = 0.011  // invisible, but still part of the visible hierarchy
    isAccessibilityElement = false
    accessibilityElementsHidden = true
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  /// Called when the Flutter scrollable comes to rest at its top edge.
  var onReachedTop: (() -> Void)?

  /// Mirrors the extent and, outside the forwarded pan, the position of the
  /// Flutter scrollable.
  func mirror(pixels: Double, min: Double, max: Double) {
    let extent = Swift.max(0, max - min)
    scrollable = extent > 0.5
    // `isTracking` stays false here: the touches land on the FlutterView.
    guard !isDragging else { return }
    let height = bounds.height + CGFloat(extent)
    if abs(contentSize.height - height) > 0.5 {
      contentSize = CGSize(width: bounds.width, height: height)
    }
    let y = CGFloat(Swift.min(Swift.max(pixels - min, 0), extent))
    if abs(contentOffset.y - y) > 0.25 {
      setContentOffset(CGPoint(x: 0, y: y), animated: false)
    }
    // UIKit expands the bar when a native fling reaches the top; Flutter's
    // fling does not count, so this is signalled explicitly.
    if pixels <= min + 0.5 { onReachedTop?() }
  }

  override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard gestureRecognizer === panGestureRecognizer else {
      return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
    guard minimizeEnabled, scrollable else { return false }
    let v = panGestureRecognizer.velocity(in: panGestureRecognizer.view)
    return abs(v.y) > abs(v.x)
  }

  @objc func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
  ) -> Bool {
    true
  }


}

/// Transparent content controller of a regular tab.
///
/// All tabs share one proxy scroll view, which moves into the selected
/// tab's view: UIKit only minimizes reliably for the scroll view it
/// observed first (on later tabs the direction even came out inverted).
final class PlaceholderViewController: UIViewController {
  private let proxy: ProxyScrollView
  /// Called once the proxy is in the window (UIKit re-attaches a scroll
  /// view's pan recognizer to it at that point).
  var onAppear: (() -> Void)?

  init(proxy: ProxyScrollView) {
    self.proxy = proxy
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  override func loadView() {
    let v = PassthroughView()
    v.backgroundColor = .clear
    v.accessibilityElementsHidden = true
    view = v
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if proxy.superview !== view {
      proxy.frame = view.bounds
      proxy.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      view.addSubview(proxy)
    }
    setContentScrollView(proxy, for: .bottom)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    onAppear?()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if proxy.superview !== view { setContentScrollView(nil, for: .bottom) }
  }
}

/// Moves the pan recognizer of the selected tab's proxy onto the
/// FlutterView, and back when the selection or the window changes.
final class PanForwarder {
  private weak var proxy: ProxyScrollView?
  private weak var target: UIView?

  func forward(_ proxy: ProxyScrollView?, to target: UIView?) {
    let attached = proxy == nil || proxy?.panGestureRecognizer.view === target
    guard proxy !== self.proxy || target !== self.target || !attached else { return }
    restore()
    guard let proxy, let target else { return }
    let pan = proxy.panGestureRecognizer
    pan.cancelsTouchesInView = false
    pan.delaysTouchesBegan = false
    pan.delaysTouchesEnded = false
    target.addGestureRecognizer(pan)
    self.proxy = proxy
    self.target = target
  }

  func restore() {
    if let proxy {
      proxy.addGestureRecognizer(proxy.panGestureRecognizer)
    }
    proxy = nil
    target = nil
  }

  deinit { restore() }
}

/// Content controller of the search tab: owns the native search field and
/// reports its state.
final class SearchPlaceholderViewController: UIViewController, UISearchResultsUpdating,
  UISearchControllerDelegate, UISearchBarDelegate
{
  var onText: ((String) -> Void)?
  var onSubmit: ((String) -> Void)?
  var onActive: ((Bool) -> Void)?
  let searchController = UISearchController(searchResultsController: nil)
  private var lastText: String?

  override func loadView() {
    let v = PassthroughView()
    v.backgroundColor = .clear
    view = v
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    searchController.searchResultsUpdater = self
    searchController.delegate = self
    searchController.searchBar.delegate = self
    searchController.obscuresBackgroundDuringPresentation = false
    navigationItem.searchController = searchController
    navigationItem.hidesSearchBarWhenScrolling = false
  }

  func setText(_ text: String) {
    lastText = text
    searchController.searchBar.text = text
  }

  func updateSearchResults(for searchController: UISearchController) {
    let text = searchController.searchBar.text ?? ""
    guard text != lastText else { return }
    lastText = text
    onText?(text)
  }

  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    onSubmit?(searchBar.text ?? "")
  }

  func didPresentSearchController(_ searchController: UISearchController) { onActive?(true) }
  func didDismissSearchController(_ searchController: UISearchController) { onActive?(false) }
}
