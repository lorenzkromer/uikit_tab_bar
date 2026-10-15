// Drives the example app with real gestures (taps, pans, typing), which
// widget tests cannot: minimizing only reacts to real pans. Attaches to an
// app started by `flutter run`, or launches the installed one.
//
//   xcodebuild -workspace Runner.xcworkspace -scheme ExampleUITests \
//     -destination 'platform=iOS Simulator,name=iPhone Air' test
//
// Set TEST_RUNNER_SHOT_DIR to keep screenshots, TEST_RUNNER_APP_BUNDLE to
// run the same gestures against another app (e.g. a pure UIKit reference
// with the same tab titles).
import XCTest

final class ExampleUITests: XCTestCase {
  let env = ProcessInfo.processInfo.environment
  lazy var app = XCUIApplication(
    bundleIdentifier: env["APP_BUNDLE"] ?? "com.kromerlorenz.uikitTabBarExample")

  override func setUp() {
    continueAfterFailure = false
    if app.state == .notRunning { app.launch() } else { app.activate() }
    if !expanded { toTop() }
    tab("Home")
    toTop()
  }

  // MARK: Gestures

  /// Point in the content area, in fractions of the screen (the tests run
  /// on phones of different sizes, e.g. iPhone Air and iPhone Duo).
  func point(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
    let size = app.frame.size
    return app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: size.width * x, dy: size.height * y))
  }

  /// Finger up: content scrolls down.
  func scrollDown() {
    point(0.4, 0.71).press(forDuration: 0.05, thenDragTo: point(0.4, 0.27), withVelocity: 800, thenHoldForDuration: 0.2)
    sleep(1)
  }

  /// Fast flings back to the top.
  func toTop() {
    for _ in 0..<2 {
      point(0.4, 0.27).press(forDuration: 0.05, thenDragTo: point(0.4, 0.77), withVelocity: 3000, thenHoldForDuration: 0.05)
    }
    sleep(2)
  }

  func tab(_ label: String) {
    app.buttons[label].firstMatch.tap()
    sleep(1)
  }

  /// Minimized, only the selected tab remains visible as a pill.
  var expanded: Bool {
    ["Home", "Entdecken", "Events", "Optionen"].filter { app.buttons[$0].exists }.count >= 3
  }

  /// iOS 27.1 vertical bar (iPhone Duo): the tabs form a column.
  var vertical: Bool {
    let home = app.buttons["Home"].firstMatch.frame, explore = app.buttons["Entdecken"].firstMatch.frame
    return abs(home.midX - explore.midX) < 1 && explore.midY > home.midY
  }

  /// First element whose label contains `text` (Flutter merges a list
  /// tile's title and subtitle into one label).
  func element(containing text: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
  }

  /// The geometry line of the options page.
  var geometryText: String { element(containing: "bottomInset").label }

  /// Scrolls the options page until `element` is in the upper part of the
  /// screen, clear of the accessory.
  func reveal(_ element: XCUIElement) {
    // Off screen, Flutter reports an empty frame.
    func visible() -> Bool {
      let f = element.frame
      return element.exists && f.height > 0 && f.minY > app.frame.height * 0.1 && f.maxY < app.frame.height * 0.7
    }
    for _ in 0..<8 where !visible() {
      point(0.4, 0.6).press(forDuration: 0.05, thenDragTo: point(0.4, 0.35), withVelocity: 600, thenHoldForDuration: 0.3)
    }
  }

  /// Ends an active search like the user would, with the close button.
  func closeSearch() {
    let close = app.buttons.matching(NSPredicate(format: "label IN {'Close', 'Schließen', 'Abbrechen', 'Cancel'}")).firstMatch
    if close.exists && close.isHittable {
      close.tap()
      sleep(1)
    }
  }

  func shot(_ name: String) {
    guard let dir = env["SHOT_DIR"] else { return }
    try? XCUIScreen.main.screenshot().pngRepresentation
      .write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
  }

  // MARK: Tests

  func testMinimizesAndExpandsOnTheStartTab() throws {
    try XCTSkipIf(vertical, "the vertical bar never minimizes")
    XCTAssertTrue(expanded)
    scrollDown()
    shot("minimized")
    XCTAssertFalse(expanded, "scrolling down minimizes")
    point(0.4, 0.33).press(forDuration: 0.05, thenDragTo: point(0.4, 0.49), withVelocity: 400, thenHoldForDuration: 0.2)
    sleep(1)
    XCTAssertFalse(expanded, "a small scroll back keeps it minimized")
    toTop()
    XCTAssertTrue(expanded, "reaching the top expands")
  }

  func testMinimizesOnTabsSelectedLater() throws {
    try XCTSkipIf(vertical, "the vertical bar never minimizes")
    for label in ["Entdecken", "Events", "Optionen"] {
      tab(label)
      scrollDown()
      XCTAssertFalse(expanded, "\(label): scrolling down minimizes")
      toTop()
      XCTAssertTrue(expanded, "\(label): reaching the top expands")
    }
    tab("Events")
    tab("Home")
    scrollDown()
    XCTAssertFalse(expanded, "Home again after switching")
    toTop()
  }

  func testPullingAtTheTopDoesNotMinimize() {
    toTop()
    XCTAssertTrue(expanded)
  }

  func testSearchFieldTypesIntoDart() {
    tab("Suche")
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 2))
    field.tap()
    sleep(1)
    app.typeText("burg")
    sleep(1)
    shot("search")
    // Like a native UISearchTab: the active field moves to the top, right
    // below the status bar (measured natively: y = 68 on an iPhone Air).
    XCTAssertLessThan(field.frame.minY, 120, "active field sits at the top")
    // With the vertical bar the status bar sits in the column instead.
    if !vertical { XCTAssertGreaterThan(field.frame.minY, 40, "below the status bar") }
    // The Flutter page renders the hits from the text Dart received.
    XCTAssertTrue(app.staticTexts["Hamburg"].exists)
    XCTAssertFalse(app.staticTexts["Berlin"].exists)
    app.typeText("\n")
    closeSearch()
    tab("Home")
  }

  // MARK: Vertical bar (iOS 27.1, iPhone Duo)

  func testVerticalBarLayout() throws {
    try XCTSkipUnless(vertical, "no vertical bar on this device")
    shot("vertical")
    let home = app.buttons["Home"].firstMatch.frame
    let screen = app.frame
    XCTAssertGreaterThan(home.minX, screen.width * 0.75, "column at the trailing edge")
    scrollDown()
    XCTAssertTrue(expanded, "the vertical bar does not minimize")
    toTop()
    tab("Optionen")
    let text = geometryText
    XCTAssertTrue(text.contains("vertikal trailing"), text)
    XCTAssertTrue(text.contains("rechts 84"), "content keeps clear of the column: \(text)")
    tab("Home")
  }

  func testVerticalBarTabsAndAccessory() throws {
    try XCTSkipUnless(vertical, "no vertical bar on this device")
    for label in ["Entdecken", "Events", "Optionen", "Home"] {
      tab(label)
      XCTAssertTrue(app.buttons[label].firstMatch.isSelected, "\(label) selected")
    }
    // On the options page, which shows the last event.
    tab("Optionen")
    toTop()
    let accessory = element(containing: "Läuft gerade")
    XCTAssertTrue(accessory.exists)
    accessory.tap()
    sleep(1)
    XCTAssertTrue(element(containing: "accessory tapped").exists)
    tab("Home")
  }

  func testVerticalBarSearch() throws {
    try XCTSkipUnless(vertical, "no vertical bar on this device")
    tab("Suche")
    closeSearch()
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 2))
    // Like natively: in the vertical layout the field sits at the top.
    XCTAssertLessThan(field.frame.minY, 150)
    shot("vertical_search")
    field.tap()
    sleep(1)
    app.typeText("burg")
    sleep(1)
    shot("vertical_searching")
    XCTAssertTrue(app.staticTexts["Hamburg"].exists)
    XCTAssertFalse(app.staticTexts["Berlin"].exists)
    app.typeText("\n")
    closeSearch()
    tab("Home")
  }

  func testVerticalBarFollowsTheRotation() throws {
    try XCTSkipUnless(vertical, "no vertical bar on this device")
    tab("Optionen")
    toTop()
    func choose(_ label: String) {
      let segment = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
      reveal(segment)
      segment.tap()
      sleep(3)
    }
    defer {
      choose("Hoch")
      choose("Frei")
      tab("Home")
    }
    // XCUIDevice does not rotate this simulator; the demo locks the
    // orientation instead (requestGeometryUpdate, like a user rotating).
    var sides: Set<String> = []
    for label in ["Quer links", "Quer rechts"] {
      choose(label)
      XCTAssertGreaterThan(app.frame.width, app.frame.height, "\(label): landscape")
      XCTAssertTrue(vertical, "\(label): still a column")
      let home = app.buttons["Home"].firstMatch.frame
      let side = home.midX > app.frame.midX ? "rechts" : "links"
      sides.insert(side)
      shot("vertical_\(side)")
      toTop()
      XCTAssertTrue(geometryText.contains("\(side) 84"), "\(label): \(geometryText)")
    }
    XCTAssertEqual(sides, ["links", "rechts"], "the column moves to the other edge")
  }

  func testVerticalBarHides() throws {
    try XCTSkipUnless(vertical, "no vertical bar on this device")
    tab("Optionen")
    toTop()
    let toggle = app.switches.matching(NSPredicate(format: "label BEGINSWITH 'Ausblenden'")).firstMatch
    reveal(toggle)
    toggle.tap()
    sleep(2)
    shot("vertical_hidden")
    XCTAssertFalse(app.buttons["Home"].firstMatch.isHittable, "the column is gone")
    toTop()
    // Measured natively: the column's width stays reserved.
    XCTAssertTrue(geometryText.contains("versteckt true"), geometryText)
    XCTAssertTrue(geometryText.contains("rechts 84"), geometryText)
    reveal(toggle)
    toggle.tap()
    sleep(2)
    XCTAssertTrue(vertical, "back")
    toTop()
    tab("Home")
  }

  func testVerticalBarCanBeDisabled() throws {
    try XCTSkipUnless(vertical, "no vertical bar on this device")
    tab("Optionen")
    let toggle = app.switches.matching(NSPredicate(format: "label BEGINSWITH 'Vertikale Bar aus'")).firstMatch
    reveal(toggle)
    toggle.tap()
    sleep(2)
    shot("vertical_disabled")
    XCTAssertFalse(vertical, "the bar moves to the bottom")
    XCTAssertTrue(expanded)
    toTop()
    XCTAssertTrue(geometryText.contains("vertikal none"), geometryText)
    reveal(toggle)
    toggle.tap()
    sleep(2)
    XCTAssertTrue(vertical, "and back")
    toTop()
    tab("Home")
  }

  func testDisabledAndReselect() {
    tab("Entdecken")
    XCTAssertTrue(app.staticTexts["Entdecken"].exists)
    tab("Entdecken")  // reselect scrolls to top; must not break selection
    tab("Home")
    XCTAssertTrue(app.staticTexts["Home"].exists)
  }
}
