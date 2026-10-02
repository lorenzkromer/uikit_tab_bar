import Flutter
import UIKit

public class UikitTabBarPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    FontRegistry.shared.assetKeyLookup = { [weak registrar] asset in
      registrar?.lookupKey(forAsset: asset) ?? asset
    }
    // Flutter's arena-based blocking would make the touch interceptor
    // "recognize" whenever the framework rejects a touch next to the glass,
    // which fails every other recognizer of that touch, including the
    // forwarded minimize pan. Hit testing alone is enough here.
    registrar.register(
      TabBarViewFactory(messenger: registrar.messenger()), withId: "uikit_tab_bar/view",
      gestureRecognizersBlockingPolicy: FlutterPlatformViewGestureRecognizersBlockingPolicyDoNotBlockGesture)
  }
}

final class TabBarViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    let channel = FlutterMethodChannel(
      name: "uikit_tab_bar/view_\(viewId)", binaryMessenger: messenger)
    if #available(iOS 26.0, *) {
      return NativeTabBarView(frame: frame, channel: channel, args: args as? [String: Any] ?? [:])
    }
    // Dart only creates the view on iOS 26+; stay harmless otherwise.
    return EmptyPlatformView()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class EmptyPlatformView: NSObject, FlutterPlatformView {
  private let empty = UIView()
  func view() -> UIView { empty }
}
