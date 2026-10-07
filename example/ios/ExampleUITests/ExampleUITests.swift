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

  func point(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
    app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
  }

  /// Finger up: content scrolls down.
  func scrollDown() {
    point(210, 650).press(forDuration: 0.05, thenDragTo: point(210, 250), withVelocity: 800, thenHoldForDuration: 0.2)
    sleep(1)
  }

  /// Fast flings back to the top.
  func toTop() {
    for _ in 0..<2 {
      point(210, 250).press(forDuration: 0.05, thenDragTo: point(210, 700), withVelocity: 3000, thenHoldForDuration: 0.05)
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

  func shot(_ name: String) {
    guard let dir = env["SHOT_DIR"] else { return }
    try? XCUIScreen.main.screenshot().pngRepresentation
      .write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
  }

  // MARK: Tests

  func testMinimizesAndExpandsOnTheStartTab() {
    XCTAssertTrue(expanded)
    scrollDown()
    shot("minimized")
    XCTAssertFalse(expanded, "scrolling down minimizes")
    point(210, 300).press(forDuration: 0.05, thenDragTo: point(210, 450), withVelocity: 400, thenHoldForDuration: 0.2)
    sleep(1)
    XCTAssertFalse(expanded, "a small scroll back keeps it minimized")
    toTop()
    XCTAssertTrue(expanded, "reaching the top expands")
  }

  func testMinimizesOnTabsSelectedLater() {
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
    XCTAssertGreaterThan(field.frame.minY, 40, "below the status bar")
    // The Flutter page renders the hits from the text Dart received.
    XCTAssertTrue(app.staticTexts["Hamburg"].exists)
    XCTAssertFalse(app.staticTexts["Berlin"].exists)
    app.typeText("\n")
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
