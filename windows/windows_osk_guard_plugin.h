#ifndef FLUTTER_PLUGIN_WINDOWS_OSK_GUARD_PLUGIN_H_
#define FLUTTER_PLUGIN_WINDOWS_OSK_GUARD_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace windows_osk_guard {

class WindowsOskGuardPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  WindowsOskGuardPlugin();

  virtual ~WindowsOskGuardPlugin();

  // Disallow copy and assign.
  WindowsOskGuardPlugin(const WindowsOskGuardPlugin&) = delete;
  WindowsOskGuardPlugin& operator=(const WindowsOskGuardPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace windows_osk_guard

#endif  // FLUTTER_PLUGIN_WINDOWS_OSK_GUARD_PLUGIN_H_
