import CoreText
import Flutter
import UIKit

extension UIColor {
  convenience init(argb: UInt32) {
    self.init(
      red: CGFloat((argb >> 16) & 0xFF) / 255, green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255, alpha: CGFloat((argb >> 24) & 0xFF) / 255)
  }
}

/// Registers font files from the Flutter assets with Core Text, once each.
final class FontRegistry {
  static let shared = FontRegistry()
  /// Maps a Flutter asset path to the file's key in the app bundle.
  var assetKeyLookup: ((String) -> String)?
  private var names: [String: String] = [:]

  func font(asset: String, size: CGFloat) -> UIFont? {
    if let name = names[asset] { return UIFont(name: name, size: size) }
    guard let key = assetKeyLookup?(asset),
      let path = Bundle.main.path(forResource: key, ofType: nil)
    else {
      NSLog("uikit_tab_bar: font asset '%@' not found", asset)
      return nil
    }
    let url = URL(fileURLWithPath: path)
    guard let provider = CGDataProvider(url: url as CFURL), let cgFont = CGFont(provider),
      let name = cgFont.postScriptName as String?
    else { return nil }
    // Fails harmlessly if the app registered the font already.
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    names[asset] = name
    return UIFont(name: name, size: size)
  }
}

/// Decoded template images sent from Dart, per view.
final class ImageStore {
  private var images: [String: UIImage] = [:]

  func add(_ raw: [String: Any]) {
    for (key, value) in raw {
      guard let data = (value as? FlutterStandardTypedData)?.data,
        let image = UIImage(data: data)
      else { continue }
      images[key] = image
    }
  }

  func image(_ spec: IconSpec?) -> UIImage? {
    switch spec {
    case .symbol(let name):
      let image = UIImage(systemName: name)
      if image == nil { NSLog("uikit_tab_bar: unknown SF Symbol '%@'", name) }
      return image
    case .image(let key, let scale):
      guard let base = images[key]?.cgImage else { return nil }
      return UIImage(cgImage: base, scale: CGFloat(scale), orientation: .up)
        .withRenderingMode(.alwaysTemplate)
    case nil:
      return nil
    }
  }
}

enum Appearance {
  static func apply(_ style: StyleSpec, to bar: UITabBar) {
    bar.tintColor = style.tint.map(UIColor.init(argb:))
    guard style.customizesItems else {
      let appearance = UITabBarAppearance()
      appearance.configureWithDefaultBackground()
      bar.standardAppearance = appearance
      bar.scrollEdgeAppearance = nil
      return
    }
    let item = UITabBarItemAppearance(style: .stacked)
    var title: [NSAttributedString.Key: Any] = [:]
    if let font = font(style) { title[.font] = font }
    var selectedTitle = title
    if let c = style.selected.map(UIColor.init(argb:)) {
      item.selected.iconColor = c
      selectedTitle[.foregroundColor] = c
    }
    if !title.isEmpty { item.normal.titleTextAttributes = title }
    if !selectedTitle.isEmpty { item.selected.titleTextAttributes = selectedTitle }
    if let o = style.titleOffset, o.count == 2 {
      let offset = UIOffset(horizontal: o[0], vertical: o[1])
      item.normal.titlePositionAdjustment = offset
      item.selected.titlePositionAdjustment = offset
    }
    for state in [item.normal, item.selected, item.disabled, item.focused] {
      if let c = style.badge { state.badgeBackgroundColor = UIColor(argb: c) }
      var badgeText: [NSAttributedString.Key: Any] = [:]
      if let c = style.badgeText { badgeText[.foregroundColor] = UIColor(argb: c) }
      if style.badgeFontSize != nil || style.badgeFontWeight != nil {
        // Measured on iOS 27: the badge resizes with its font.
        badgeText[.font] = UIFont.systemFont(
          ofSize: CGFloat(style.badgeFontSize ?? 13), weight: weight(style.badgeFontWeight ?? 400))
      }
      if !badgeText.isEmpty { state.badgeTextAttributes = badgeText }
      if let o = style.badgeOffset, o.count == 2 {
        // Measured on iOS 27: positive horizontal moves toward the leading
        // edge (left in LTR, right in RTL), so the Dart value is negated.
        state.badgePositionAdjustment = UIOffset(horizontal: -o[0], vertical: o[1])
      }
    }
    let appearance = UITabBarAppearance()
    appearance.configureWithDefaultBackground()
    appearance.stackedLayoutAppearance = item
    appearance.inlineLayoutAppearance = item
    appearance.compactInlineLayoutAppearance = item
    bar.standardAppearance = appearance
    bar.scrollEdgeAppearance = appearance
  }

  private static func font(_ style: StyleSpec) -> UIFont? {
    let size = CGFloat(style.fontSize ?? 10)
    if let asset = style.fontAsset, let font = FontRegistry.shared.font(asset: asset, size: size) {
      return font
    }
    guard style.fontSize != nil || style.fontWeight != nil else { return nil }
    return .systemFont(ofSize: size, weight: weight(style.fontWeight ?? 500))
  }

  private static func weight(_ w: Int) -> UIFont.Weight {
    switch w {
    case ..<150: return .ultraLight
    case ..<250: return .thin
    case ..<350: return .light
    case ..<450: return .regular
    case ..<550: return .medium
    case ..<650: return .semibold
    case ..<750: return .bold
    case ..<850: return .heavy
    default: return .black
    }
  }
}
