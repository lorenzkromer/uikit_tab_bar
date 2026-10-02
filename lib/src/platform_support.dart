import 'package:flutter/foundation.dart';

import 'ios_version_stub.dart' if (dart.library.io) 'ios_version_io.dart';

/// Lowest iOS version that gets the native bar.
const int kMinNativeIosVersion = 26;

/// Forces the native bar (`true`) or the fallback (`false`); `null` decides
/// by platform. For tests and debugging.
bool? debugUseNativeTabBar;

int? _version;

/// Whether this device gets the native UIKit bar.
bool get nativeTabBarSupported {
  final forced = debugUseNativeTabBar;
  if (forced != null) return forced;
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
  _version ??= iosMajorVersion() ?? 0;
  return _version! >= kMinNativeIosVersion;
}
