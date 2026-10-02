import 'dart:io';

/// Major iOS version, or `null` when not running on iOS.
int? iosMajorVersion() {
  if (!Platform.isIOS) return null;
  // e.g. "Version 26.0 (Build 23A341)"
  final match = RegExp(r'(\d+)\.\d+').firstMatch(Platform.operatingSystemVersion);
  return match == null ? null : int.tryParse(match.group(1)!);
}
