import Flutter
import UIKit
import XCTest

@testable import uikit_tab_bar

/// Native side of the channel protocol: parsing the Dart state and diffing.
class BarStateTests: XCTestCase {
  func state(
    tabs: [[String: Any]] = [tab("home"), tab("explore")], selected: String = "home",
    extra: [String: Any] = [:]
  ) -> BarState {
    var m: [String: Any] = ["tabs": tabs, "selectedId": selected]
    m.merge(extra) { _, b in b }
    return BarState(m)
  }

  static func tab(_ id: String, _ extra: [String: Any] = [:]) -> [String: Any] {
    var m: [String: Any] = ["id": id, "title": id.capitalized, "icon": ["symbol": "circle"]]
    m.merge(extra) { _, b in b }
    return m
  }

  func tab(_ id: String, _ extra: [String: Any] = [:]) -> [String: Any] { Self.tab(id, extra) }

  func testParsesTabsIconsAndOptions() {
    let s = state(
      tabs: [
        tab("home", ["badge": "3", "enabled": false, "selectedIcon": ["symbol": "house.fill"]]),
        tab("img", ["icon": ["image": "i1", "scale": 2.0]]),
      ],
      extra: [
        "search": ["id": "search", "automaticallyActivatesSearch": true],
        "prominentId": "img", "minimizeBehavior": "onScrollDown", "hidden": true,
        "style": [
          "tint": NSNumber(value: Int64(0xFF11_2233)), "titleOffset": [0, -2], "badgeOffset": [-8, 2],
        ],
        "brightness": "dark",
      ])
    XCTAssertEqual(s.tabs.map(\.id), ["home", "img"])
    XCTAssertEqual(s.tabs[0].icon, .symbol("circle"))
    XCTAssertEqual(s.tabs[0].selectedIcon, .symbol("house.fill"))
    XCTAssertEqual(s.tabs[0].badge, "3")
    XCTAssertFalse(s.tabs[0].enabled)
    XCTAssertEqual(s.tabs[1].icon, .image(key: "i1", scale: 2))
    XCTAssertEqual(s.search?.automaticallyActivatesSearch, true)
    XCTAssertEqual(s.prominentId, "img")
    XCTAssertEqual(s.minimizeBehavior, "onScrollDown")
    XCTAssertTrue(s.hidden)
    XCTAssertEqual(s.style.tint, 0xFF11_2233)
    XCTAssertEqual(s.style.titleOffset, [0, -2])
    XCTAssertEqual(s.style.badgeOffset, [-8, 2])
    XCTAssertTrue(s.style.customizesItems)
    XCTAssertEqual(s.brightness, "dark")
  }

  func testDefaultsForMissingValues() {
    let s = BarState([:])
    XCTAssertTrue(s.tabs.isEmpty)
    XCTAssertNil(s.search)
    XCTAssertEqual(s.minimizeBehavior, "automatic")
    XCTAssertFalse(s.style.customizesItems)
  }

  func testFirstStateChangesEverything() {
    let d = BarDiff.between(nil, state())
    XCTAssertTrue(d.structure)
    XCTAssertEqual(d.changedTabs, ["home", "explore"])
    XCTAssertTrue(d.style && d.accessory && d.hidden && d.minimize)
  }

  func testIdenticalStateIsEmpty() {
    XCTAssertTrue(BarDiff.between(state(), state()).isEmpty)
  }

  func testSelectionAloneIsNotADiff() {
    // Selection is always reconciled against UIKit, not diffed.
    XCTAssertTrue(BarDiff.between(state(selected: "home"), state(selected: "explore")).isEmpty)
  }

  func testChangedTabOnly() {
    let d = BarDiff.between(state(), state(tabs: [tab("home"), tab("explore", ["badge": "1"])]))
    XCTAssertFalse(d.structure)
    XCTAssertEqual(d.changedTabs, ["explore"])
    XCTAssertFalse(d.style)
  }

  func testReorderIsStructural() {
    let d = BarDiff.between(state(), state(tabs: [tab("explore"), tab("home")]))
    XCTAssertTrue(d.structure)
    XCTAssertTrue(d.changedTabs.isEmpty)
  }

  func testHiddenTabLeavesTheBarButKeepsItsSpec() {
    let hidden = state(tabs: [tab("home"), tab("explore", ["hidden": true])])
    XCTAssertEqual(hidden.rootIds, ["home"])
    let d = BarDiff.between(state(), hidden)
    XCTAssertTrue(d.structure)
    XCTAssertEqual(d.changedTabs, ["explore"])
  }

  func testSearchTabIsLastRoot() {
    let s = state(extra: ["search": ["id": "find"]])
    XCTAssertEqual(s.rootIds, ["home", "explore", "find"])
    XCTAssertTrue(BarDiff.between(state(), s).structure)
  }

  func testOptionChanges() {
    let base = state()
    XCTAssertTrue(BarDiff.between(base, state(extra: ["hidden": true])).hidden)
    XCTAssertTrue(BarDiff.between(base, state(extra: ["prominentId": "explore"])).prominent)
    XCTAssertTrue(BarDiff.between(base, state(extra: ["minimizeBehavior": "never"])).minimize)
    XCTAssertTrue(BarDiff.between(base, state(extra: ["brightness": "dark"])).brightness)
    XCTAssertTrue(BarDiff.between(base, state(extra: ["rtl": true])).rtl)
    XCTAssertTrue(BarDiff.between(base, state(extra: ["accessory": ["title": "Now"]])).accessory)
    XCTAssertTrue(BarDiff.between(base, state(extra: ["style": ["badge": NSNumber(value: 1)]])).style)
  }

  func testBadgeOffsetIsAppliedMirroredHorizontally() {
    // UIKit's horizontal badge adjustment points toward the leading edge
    // under Liquid Glass; Dart's dx points toward the trailing edge.
    let bar = UITabBar()
    Appearance.apply(StyleSpec(["badgeOffset": [-8, 2]]), to: bar)
    let adjustment = bar.standardAppearance.stackedLayoutAppearance.normal.badgePositionAdjustment
    XCTAssertEqual(adjustment.horizontal, 8)
    XCTAssertEqual(adjustment.vertical, 2)
    XCTAssertTrue(StyleSpec(["badgeOffset": [0, 1]]).customizesItems)
  }

  func testColorFromARGB() {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    UIColor(argb: 0x80FF_0000).getRed(&r, green: &g, blue: &b, alpha: &a)
    XCTAssertEqual(r, 1, accuracy: 0.001)
    XCTAssertEqual(g, 0, accuracy: 0.001)
    XCTAssertEqual(a, 128.0 / 255, accuracy: 0.001)
  }
}
