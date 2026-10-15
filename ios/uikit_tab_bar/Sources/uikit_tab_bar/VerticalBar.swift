import ObjectiveC
import UIKit

/// The vertical bar of iOS 27.1: on hardware that supports it (iPhone Duo)
/// the system moves the tab bar into a column at the leading or trailing
/// edge, and the status bar with it. The window reserves that column as a
/// leading or trailing safe area inset.
///
/// The APIs are used dynamically. They exist only in the iOS 27.1 SDK, and
/// Xcode 27.1 ships the same Swift compiler as Xcode 27.0, so
/// `#if compiler(...)` cannot tell the two SDKs apart. This way the package
/// builds with every supported Xcode, and the vertical bar works whenever
/// the app runs on iOS 27.1 or later.
enum VerticalBar {
  enum Edge: String {
    case none, leading, trailing
  }

  /// `UITraitCollection.verticalBarEdge`. UIKit reports `.unspecified` once
  /// the vertical bar is disabled for the window, so this is also the
  /// effective state.
  static func edge(of traits: UITraitCollection) -> Edge {
    guard traits.responds(to: NSSelectorFromString("verticalBarEdge")),
      let raw = traits.value(forKey: "verticalBarEdge") as? Int
    else { return .none }
    switch raw {
    case 1: return .leading
    case 2: return .trailing
    default: return .none
    }
  }

  /// Whether this iOS knows the vertical bar at all.
  static var isAvailable: Bool {
    UIViewController.instancesRespond(to: preferredSelector)
  }

  /// Disables (or re-enables) the vertical bar for the presentation that
  /// `viewController` belongs to.
  ///
  /// UIKit resolves the preference from the root of the window (or of the
  /// presentation) down through `childForPreferredVerticalBarBehavior`.
  /// The tab bar controller is a child of the Flutter view controller,
  /// which does not forward, so the override goes to that root.
  static func setDisabled(_ disabled: Bool, for viewController: UIViewController) {
    guard isAvailable else { return }
    var root = viewController
    while let parent = root.parent { root = parent }
    let current = objc_getAssociatedObject(root, &disabledKey) as? Bool ?? false
    guard current != disabled else { return }
    installOverrides(on: type(of: root))
    objc_setAssociatedObject(root, &disabledKey, disabled, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    root.perform(NSSelectorFromString("setNeedsUpdateOfVerticalBarConfiguration"))
  }

  private static var disabledKey: UInt8 = 0
  private static var patched: Set<ObjectIdentifier> = []
  private static let preferredSelector = NSSelectorFromString("preferredVerticalBarBehavior")
  private static let childSelector = NSSelectorFromString("childViewControllerForPreferredVerticalBarBehavior")

  private static func isDisabled(_ object: AnyObject) -> Bool {
    objc_getAssociatedObject(object, &disabledKey) as? Bool ?? false
  }

  /// Overrides the two getters on `cls`. The overrides only differ from the
  /// original for instances marked through `setDisabled`.
  private static func installOverrides(on cls: AnyClass) {
    guard patched.insert(ObjectIdentifier(cls)).inserted else { return }

    typealias IntGetter = @convention(c) (AnyObject, Selector) -> Int
    typealias ObjectGetter = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?

    if let method = class_getInstanceMethod(cls, preferredSelector) {
      let original = unsafeBitCast(method_getImplementation(method), to: IntGetter.self)
      let selector = preferredSelector
      let block: @convention(block) (AnyObject) -> Int = { object in
        // 1 = UIVerticalBarBehaviorDisabled
        isDisabled(object) ? 1 : original(object, selector)
      }
      replace(cls, preferredSelector, imp_implementationWithBlock(block), method)
    }
    if let method = class_getInstanceMethod(cls, childSelector) {
      let original = unsafeBitCast(method_getImplementation(method), to: ObjectGetter.self)
      let selector = childSelector
      let block: @convention(block) (AnyObject) -> Unmanaged<AnyObject>? = { object in
        // Keep the decision at this root instead of a forwarded child.
        isDisabled(object) ? nil : original(object, selector)
      }
      replace(cls, childSelector, imp_implementationWithBlock(block), method)
    }
  }

  /// Adds the override to `cls`, or replaces the implementation if `cls`
  /// itself defines the method (the captured original is then its own).
  private static func replace(_ cls: AnyClass, _ selector: Selector, _ imp: IMP, _ method: Method) {
    if !class_addMethod(cls, selector, imp, method_getTypeEncoding(method)) {
      method_setImplementation(method, imp)
    }
  }
}
