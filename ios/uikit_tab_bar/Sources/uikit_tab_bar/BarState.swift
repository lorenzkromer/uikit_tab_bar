import Foundation

// Typed mirror of the Dart wire format (lib/src/protocol.dart). Dart always
// sends the full state; `BarDiff` tells the view what actually changed so
// UIKit only animates real changes.

enum IconSpec: Equatable {
  case symbol(String)
  case image(key: String, scale: Double)

  init?(_ value: Any?) {
    guard let m = value as? [String: Any] else { return nil }
    if let name = m["symbol"] as? String {
      self = .symbol(name)
    } else if let key = m["image"] as? String {
      self = .image(key: key, scale: (m["scale"] as? NSNumber)?.doubleValue ?? 3)
    } else {
      return nil
    }
  }
}

struct TabSpec: Equatable {
  var id: String
  var title: String
  var icon: IconSpec?
  var selectedIcon: IconSpec?
  var badge: String?
  var subtitle: String?
  var enabled: Bool
  var hidden: Bool

  init(_ m: [String: Any]) {
    id = m["id"] as? String ?? ""
    title = m["title"] as? String ?? ""
    icon = IconSpec(m["icon"])
    selectedIcon = IconSpec(m["selectedIcon"])
    badge = m["badge"] as? String
    subtitle = m["subtitle"] as? String
    enabled = m["enabled"] as? Bool ?? true
    hidden = m["hidden"] as? Bool ?? false
  }
}

struct SearchSpec: Equatable {
  var id: String
  var title: String?
  var placeholder: String?
  var automaticallyActivatesSearch: Bool

  init?(_ value: Any?) {
    guard let m = value as? [String: Any] else { return nil }
    id = m["id"] as? String ?? "search"
    title = m["title"] as? String
    placeholder = m["placeholder"] as? String
    automaticallyActivatesSearch = m["automaticallyActivatesSearch"] as? Bool ?? false
  }
}

struct AccessoryActionSpec: Equatable {
  var id: String
  var icon: IconSpec?
  var label: String?
}

struct AccessorySpec: Equatable {
  var title: String
  var subtitle: String?
  var icon: IconSpec?
  var actions: [AccessoryActionSpec]

  init?(_ value: Any?) {
    guard let m = value as? [String: Any] else { return nil }
    title = m["title"] as? String ?? ""
    subtitle = m["subtitle"] as? String
    icon = IconSpec(m["icon"])
    actions = (m["actions"] as? [[String: Any]] ?? []).map {
      AccessoryActionSpec(
        id: $0["id"] as? String ?? "", icon: IconSpec($0["icon"]), label: $0["label"] as? String)
    }
  }
}

struct ToolbarItemSpec: Equatable {
  var id: String
  var icon: IconSpec?
  var label: String
  var badge: String?
  /// "low", "standard" or "high".
  var priority: String
  var prominent: Bool
  var enabled: Bool

  init(_ m: [String: Any]) {
    id = m["id"] as? String ?? ""
    icon = IconSpec(m["icon"])
    label = m["label"] as? String ?? ""
    badge = m["badge"] as? String
    priority = m["priority"] as? String ?? "standard"
    prominent = m["prominent"] as? Bool ?? false
    enabled = m["enabled"] as? Bool ?? true
  }
}

struct ToolbarMenuItemSpec: Equatable {
  var id: String
  var label: String
  var icon: IconSpec?
  var destructive: Bool
  var enabled: Bool

  init(_ m: [String: Any]) {
    id = m["id"] as? String ?? ""
    label = m["label"] as? String ?? ""
    icon = IconSpec(m["icon"])
    destructive = m["destructive"] as? Bool ?? false
    enabled = m["enabled"] as? Bool ?? true
  }
}

/// The app's buttons in the vertical bar (iOS 27.1).
struct ToolbarSpec: Equatable {
  var navigation: [ToolbarItemSpec]
  var groups: [[ToolbarItemSpec]]
  /// Groups at the bottom of the column (`toolbarItems`).
  var bottomGroups: [[ToolbarItemSpec]]
  var menu: [ToolbarMenuItemSpec]
  /// "automatic", "prefersTabBar" or "prefersToolbar".
  var compression: String

  init?(_ value: Any?) {
    guard let m = value as? [String: Any] else { return nil }
    navigation = (m["navigation"] as? [[String: Any]] ?? []).map(ToolbarItemSpec.init)
    groups = (m["groups"] as? [[[String: Any]]] ?? []).map { $0.map(ToolbarItemSpec.init) }
    bottomGroups = (m["bottomGroups"] as? [[[String: Any]]] ?? []).map { $0.map(ToolbarItemSpec.init) }
    menu = (m["menu"] as? [[String: Any]] ?? []).map(ToolbarMenuItemSpec.init)
    compression = m["compression"] as? String ?? "automatic"
  }
}

struct StyleSpec: Equatable {
  var tint: UInt32?
  var selected: UInt32?
  var fontAsset: String?
  var fontSize: Double?
  var fontWeight: Int?
  var titleOffset: [Double]?
  var badge: UInt32?
  var badgeText: UInt32?
  /// Dart semantics: dx toward the trailing edge, dy down.
  var badgeOffset: [Double]?
  var badgeFontSize: Double?
  var badgeFontWeight: Int?

  init(_ value: Any?) {
    let m = value as? [String: Any] ?? [:]
    func color(_ k: String) -> UInt32? {
      (m[k] as? NSNumber).map { UInt32(truncatingIfNeeded: $0.int64Value) }
    }
    tint = color("tint")
    selected = color("selected")
    fontAsset = m["fontAsset"] as? String
    fontSize = (m["fontSize"] as? NSNumber)?.doubleValue
    fontWeight = (m["fontWeight"] as? NSNumber)?.intValue
    titleOffset = (m["titleOffset"] as? [NSNumber])?.map(\.doubleValue)
    badge = color("badge")
    badgeText = color("badgeText")
    badgeOffset = (m["badgeOffset"] as? [NSNumber])?.map(\.doubleValue)
    badgeFontSize = (m["badgeFontSize"] as? NSNumber)?.doubleValue
    badgeFontWeight = (m["badgeFontWeight"] as? NSNumber)?.intValue
  }

  /// Whether an item appearance is needed at all (otherwise system default).
  var customizesItems: Bool {
    selected != nil || fontAsset != nil || fontSize != nil || fontWeight != nil
      || titleOffset != nil || badge != nil || badgeText != nil || badgeOffset != nil
      || badgeFontSize != nil || badgeFontWeight != nil
  }
}

struct BarState: Equatable {
  var tabs: [TabSpec]
  var search: SearchSpec?
  var selectedId: String
  var prominentId: String?
  var minimizeBehavior: String
  var hidden: Bool
  /// "visible", "hiddenInVerticalBar" or "hidden".
  var tabsVisibility: String
  var accessory: AccessorySpec?
  var toolbar: ToolbarSpec?
  var style: StyleSpec
  var brightness: String
  var rtl: Bool
  /// "automatic" or "disabled" (iOS 27.1 vertical bar).
  var verticalBar: String

  init(_ m: [String: Any]) {
    tabs = (m["tabs"] as? [[String: Any]] ?? []).map(TabSpec.init)
    search = SearchSpec(m["search"])
    selectedId = m["selectedId"] as? String ?? ""
    prominentId = m["prominentId"] as? String
    minimizeBehavior = m["minimizeBehavior"] as? String ?? "automatic"
    hidden = m["hidden"] as? Bool ?? false
    tabsVisibility = m["tabsVisibility"] as? String ?? "visible"
    accessory = AccessorySpec(m["accessory"])
    toolbar = ToolbarSpec(m["toolbar"])
    style = StyleSpec(m["style"])
    brightness = m["brightness"] as? String ?? "light"
    rtl = m["rtl"] as? Bool ?? false
    verticalBar = m["verticalBar"] as? String ?? "automatic"
  }

  /// Visible root tab ids in display order, search tab last. Hidden tabs
  /// are left out: `UITab.isHidden` only affects the sidebar.
  var rootIds: [String] {
    tabs.filter { !$0.hidden }.map(\.id) + (search.map { [$0.id] } ?? [])
  }
}

/// What changed between two states.
struct BarDiff: Equatable {
  var structure = false
  var changedTabs: Set<String> = []
  var search = false
  var prominent = false
  var minimize = false
  var hidden = false
  var accessory = false
  var toolbar = false
  var style = false
  var brightness = false
  var rtl = false
  var verticalBar = false

  var isEmpty: Bool { self == BarDiff() }

  static func between(_ old: BarState?, _ new: BarState) -> BarDiff {
    guard let old else {
      var all = BarDiff(
        structure: true, search: true, prominent: true, minimize: true, hidden: true,
        accessory: true, toolbar: true, style: true, brightness: true, rtl: true, verticalBar: true)
      all.changedTabs = Set(new.tabs.map(\.id))
      return all
    }
    var d = BarDiff()
    d.structure = old.rootIds != new.rootIds
    let previous = Dictionary(old.tabs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    d.changedTabs = Set(new.tabs.filter { previous[$0.id] != $0 }.map(\.id))
    d.search = old.search != new.search
    d.prominent = old.prominentId != new.prominentId
    d.minimize = old.minimizeBehavior != new.minimizeBehavior
    d.hidden = old.hidden != new.hidden || old.tabsVisibility != new.tabsVisibility
    d.accessory = old.accessory != new.accessory
    d.toolbar = old.toolbar != new.toolbar
    d.style = old.style != new.style
    d.brightness = old.brightness != new.brightness
    d.rtl = old.rtl != new.rtl
    d.verticalBar = old.verticalBar != new.verticalBar
    return d
  }
}
