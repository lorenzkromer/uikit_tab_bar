/// The native iOS tab bar (UIKit, Liquid Glass) for Flutter, with a
/// Cupertino fallback for iOS < 26 and other platforms.
library;

export 'src/controller.dart' show UIKitTabBarController, UIKitTabBarScrollListener;
export 'src/model.dart';
export 'src/platform_support.dart' show debugUseNativeTabBar;
export 'src/scaffold.dart' show UIKitTabScaffold;
export 'src/tab_bar.dart' show UIKitTabBar, UIKitTabBarScope;
