import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'windows_osk_guard_platform_interface.dart';

/// An implementation of [WindowsOskGuardPlatform] that uses method channels.
class MethodChannelWindowsOskGuard extends WindowsOskGuardPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('windows_osk_guard');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
