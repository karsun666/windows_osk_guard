import 'package:flutter_test/flutter_test.dart';
import 'package:windows_osk_guard/windows_osk_guard.dart';
import 'package:windows_osk_guard/windows_osk_guard_platform_interface.dart';
import 'package:windows_osk_guard/windows_osk_guard_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockWindowsOskGuardPlatform
    with MockPlatformInterfaceMixin
    implements WindowsOskGuardPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final WindowsOskGuardPlatform initialPlatform = WindowsOskGuardPlatform.instance;

  test('$MethodChannelWindowsOskGuard is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelWindowsOskGuard>());
  });

  test('getPlatformVersion', () async {
    WindowsOskGuard windowsOskGuardPlugin = WindowsOskGuard();
    MockWindowsOskGuardPlatform fakePlatform = MockWindowsOskGuardPlatform();
    WindowsOskGuardPlatform.instance = fakePlatform;

    expect(await windowsOskGuardPlugin.getPlatformVersion(), '42');
  });
}
