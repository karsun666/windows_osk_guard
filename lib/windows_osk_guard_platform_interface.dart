import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'windows_osk_guard_method_channel.dart';

abstract class WindowsOskGuardPlatform extends PlatformInterface {
  /// Constructs a WindowsOskGuardPlatform.
  WindowsOskGuardPlatform() : super(token: _token);

  static final Object _token = Object();

  static WindowsOskGuardPlatform _instance = MethodChannelWindowsOskGuard();

  /// The default instance of [WindowsOskGuardPlatform] to use.
  ///
  /// Defaults to [MethodChannelWindowsOskGuard].
  static WindowsOskGuardPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [WindowsOskGuardPlatform] when
  /// they register themselves.
  static set instance(WindowsOskGuardPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
