#include "include/windows_osk_guard/windows_osk_guard_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "windows_osk_guard_plugin.h"

void WindowsOskGuardPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  windows_osk_guard::WindowsOskGuardPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
