#ifdef WINVER
#undef WINVER
#endif
#define WINVER 0x0A00

#ifdef _WIN32_WINNT
#undef _WIN32_WINNT
#endif
#define _WIN32_WINNT 0x0A00

#ifndef WM_POINTERFIRST
#define WM_POINTERFIRST 0x0245
#endif
#ifndef WM_POINTERLAST
#define WM_POINTERLAST 0x0256
#endif
#ifndef WM_POINTERDOWN
#define WM_POINTERDOWN 0x0246
#endif
#ifndef WM_POINTERUP
#define WM_POINTERUP 0x0247
#endif
#ifndef WM_POINTERUPDATE
#define WM_POINTERUPDATE 0x0245
#endif

#include "windows_osk_guard_plugin.h"

#include <windows.h>
#include <initguid.h>
#include <commctrl.h>
#include <shellapi.h>
#include <shobjidl.h>
#include <psapi.h>
#include <winsvc.h>
#include <dwmapi.h>
#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "psapi.lib")
#pragma comment(lib, "dwmapi.lib")

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <vector>
#include <mutex>

// Define COM GUIDs for touch keyboard invocation
// {4CE576FA-83DC-4F88-951C-9D0782B4E376}
DEFINE_GUID(CLSID_UIHostNoLaunch, 0x4ce576fa, 0x83dc, 0x4f88, 0x95, 0x1c, 0x9d, 0x07, 0x82, 0xb4, 0xe3, 0x76);

// {37C994E7-432B-4834-A2F7-DCE1F13B834B}
DEFINE_GUID(IID_ITipInvocation, 0x37c994e7, 0x432b, 0x4834, 0xa2, 0xf7, 0xdc, 0xe1, 0xf1, 0x3b, 0x83, 0x4b);

// {d5120aa3-46ba-44c5-822d-ca8092c1fc72}
DEFINE_GUID(CLSID_FrameworkInputPane, 0xd5120aa3, 0x46ba, 0x44c5, 0x82, 0x2d, 0xca, 0x80, 0x92, 0xc1, 0xfc, 0x72);

// {5752238b-24f0-498a-af34-f8f41505d985}
DEFINE_GUID(IID_IFrameworkInputPane, 0x5752238b, 0x24f0, 0x498a, 0xaf, 0x34, 0xf8, 0xf4, 0x15, 0x05, 0xd9, 0x85);

struct ITipInvocation : IUnknown {
  virtual HRESULT STDMETHODCALLTYPE Toggle(HWND hwnd) = 0;
};

static bool g_touch_to_mouse_enabled = true;
static bool g_last_input_was_touch = false;
static HWND g_main_window_handle = nullptr;
static HWND g_child_window_handle = nullptr;
static POINT g_start_pt = { 0, 0 };
static POINT g_current_pt = { 0, 0 };
static bool g_is_dragging = false;
static int g_active_pointer_count = 0;
static bool g_multi_touch_active = false;
static bool g_emulating_mouse_down = false;
static bool g_osk_open_by_us = false;

static UINT32 g_first_pointer_id = 0;
static POINT g_first_pointer_pt = { 0, 0 };
static bool g_allow_touch_bypass = false;

static bool EnsureComApartment() {
  HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (SUCCEEDED(hr)) {
    return true;
  }
  if (hr == RPC_E_CHANGED_MODE || hr == S_FALSE) {
    return true;
  }
  return false;
}

static bool InvokeTipToggle() {
  if (!EnsureComApartment()) {
    return false;
  }

  ITipInvocation* pTipInvocation = nullptr;
  HRESULT hr = CoCreateInstance(CLSID_UIHostNoLaunch, nullptr,
                                CLSCTX_INPROC_HANDLER | CLSCTX_LOCAL_SERVER,
                                IID_ITipInvocation, (void**)&pTipInvocation);
  if (FAILED(hr) || pTipInvocation == nullptr) {
    return false;
  }

  HWND target_hwnd = g_main_window_handle;
  if (target_hwnd == nullptr) {
    target_hwnd = GetActiveWindow();
  }
  if (target_hwnd == nullptr) {
    target_hwnd = GetDesktopWindow();
  }

  pTipInvocation->Toggle(target_hwnd);
  pTipInvocation->Release();
  return true;
}



extern "C" __declspec(dllexport) void ActivateTouchSession(int x, int y) {
  if (g_child_window_handle == nullptr) return;

  POINT pt = { x, y };
  ClientToScreen(g_child_window_handle, &pt);

  LPARAM lParamCoord = MAKELPARAM(pt.x, pt.y);
  WPARAM wParamDown = MAKEWPARAM(999, POINTER_FLAG_DOWN | POINTER_FLAG_INRANGE | POINTER_FLAG_INCONTACT);
  WPARAM wParamUp = MAKEWPARAM(999, POINTER_FLAG_UP | POINTER_FLAG_INRANGE);

  g_allow_touch_bypass = true;
  PostMessage(g_child_window_handle, WM_POINTERDOWN, wParamDown, lParamCoord);
  PostMessage(g_child_window_handle, WM_POINTERUP, wParamUp, lParamCoord);
}

static bool IsWindowCloaked(HWND hwnd) {
  if (hwnd == nullptr) return false;
  int cloaked = 0;
  HRESULT hr = DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, &cloaked, sizeof(cloaked));
  if (SUCCEEDED(hr)) {
    return cloaked != 0;
  }
  return false;
}

static bool IsWindowReallyVisible(HWND hwnd) {
  if (hwnd == nullptr) return false;
  if (!IsWindowVisible(hwnd)) return false;
  if (IsWindowCloaked(hwnd)) return false;
  if (IsIconic(hwnd)) return false;
  RECT rect;
  if (GetWindowRect(hwnd, &rect)) {
    int width = rect.right - rect.left;
    int height = rect.bottom - rect.top;
    if (width > 100 && height > 100) {
      return true;
    }
  }
  return false;
}

// ─── P2: Dual-path detection ─────────────────────────────────────────────────
// Method A: Legacy FindWindow by class/title (works Win10, sometimes Win11)
static bool IsKeyboardVisibleMethodA() {
  HWND hwnd10 = FindWindow(L"IPTIP_Main_Window", nullptr);
  if (hwnd10 != nullptr) {
    if (IsWindowReallyVisible(hwnd10)) return true;
  }

  HWND hwnd11 = FindWindow(nullptr, L"Microsoft Text Input Application");
  if (hwnd11 != nullptr) {
    if (IsWindowReallyVisible(hwnd11)) return true;
  }

  HWND hwndAlt = FindWindow(nullptr, L"Windows Input Experience");
  if (hwndAlt != nullptr) {
    if (IsWindowReallyVisible(hwndAlt)) return true;
  }

  return false;
}

// Method B: ApplicationFrameWindow child enumeration (Win11 reliable path)
static HWND g_found_core_window = nullptr;
static BOOL CALLBACK EnumChildForCoreWindow(HWND hwndChild, LPARAM lParam) {
  wchar_t className[256];
  GetClassName(hwndChild, className, 256);
  if (wcscmp(className, L"Windows.UI.Core.CoreWindow") == 0) {
    g_found_core_window = hwndChild;
    return FALSE; // stop enumeration
  }
  return TRUE;
}

static bool IsKeyboardVisibleMethodB() {
  HWND hwndFrame = nullptr;
  while ((hwndFrame = FindWindowEx(nullptr, hwndFrame, L"ApplicationFrameWindow", nullptr)) != nullptr) {
    wchar_t title[512];
    GetWindowText(hwndFrame, title, 512);
    if (wcsstr(title, L"Microsoft Text Input Application") != nullptr ||
        wcsstr(title, L"Windows Input Experience") != nullptr) {
      bool frameVisible = IsWindowVisible(hwndFrame);
      bool frameCloaked = IsWindowCloaked(hwndFrame);
      if (!frameVisible && !frameCloaked) continue; // check if frame is active in some way
      g_found_core_window = nullptr;
      EnumChildWindows(hwndFrame, EnumChildForCoreWindow, 0);
      if (g_found_core_window != nullptr) {
        bool coreVisible = IsWindowVisible(g_found_core_window);
        bool coreCloaked = IsWindowCloaked(g_found_core_window);
        RECT rect = {};
        GetWindowRect(g_found_core_window, &rect);
        int w = rect.right - rect.left;
        int h = rect.bottom - rect.top;
        if (coreVisible && !coreCloaked && w > 50 && h > 50) {
          return true;
        }
      }
    }
  }
  return false;
}

// Forward declare COM-based input pane visibility detection (Method C)
extern "C" __declspec(dllexport) bool IsOskVisibleViaInputPane();

// Combined: uses all three methods (FindWindow, AppFrameWindow children, and COM InputPane Location), returning combined result
static bool IsKeyboardVisible() {
  bool a = IsKeyboardVisibleMethodA();
  bool b = IsKeyboardVisibleMethodB();
  bool c = IsOskVisibleViaInputPane();
  return a || b || c;
}

// ─── P0: TabTip Health Check ──────────────────────────────────────────────────
// Check if TabTip.exe or TextInputHost.exe is alive (no admin required)
static bool IsTabTipProcessAlive() {
  DWORD pids[2048];
  DWORD cbNeeded = 0;
  if (!EnumProcesses(pids, sizeof(pids), &cbNeeded)) return false;
  DWORD numProcesses = cbNeeded / sizeof(DWORD);
  for (DWORD i = 0; i < numProcesses; i++) {
    if (pids[i] == 0) continue;
    HANDLE hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pids[i]);
    if (!hProcess) continue;
    wchar_t path[MAX_PATH] = {};
    DWORD pathLen = MAX_PATH;
    if (QueryFullProcessImageName(hProcess, 0, path, &pathLen)) {
      std::wstring ws(path);
      if (ws.find(L"TabTip.exe") != std::wstring::npos ||
          ws.find(L"TextInputHost.exe") != std::wstring::npos) {
        DWORD exitCode = 0;
        bool alive = GetExitCodeProcess(hProcess, &exitCode) && exitCode == STILL_ACTIVE;
        CloseHandle(hProcess);
        if (alive) return true;
      }
    }
    CloseHandle(hProcess);
  }
  return false;
}

// Check TabletInputService via SCM (no admin needed for query)
static bool IsTabletServiceRunning() {
  SC_HANDLE scm = OpenSCManager(nullptr, nullptr, SC_MANAGER_ENUMERATE_SERVICE);
  if (!scm) return false;
  SC_HANDLE svc = OpenService(scm, L"TabletInputService", SERVICE_QUERY_STATUS);
  bool running = false;
  if (svc) {
    SERVICE_STATUS_PROCESS status = {};
    DWORD needed = 0;
    if (QueryServiceStatusEx(svc, SC_STATUS_PROCESS_INFO, (LPBYTE)&status, sizeof(status), &needed)) {
      running = (status.dwCurrentState == SERVICE_RUNNING);
    }
    CloseServiceHandle(svc);
  }
  CloseServiceHandle(scm);
  return running;
}

// Attempt recovery: if TabTip/TextInputHost not alive, launch TabTip.exe
// Returns: 0=already alive, 1=launched OK, -1=launch failed
static int EnsureTabTipHealthy() {
  if (IsTabTipProcessAlive()) return 0;  // already alive
  wchar_t path[MAX_PATH];
  DWORD expanded = ExpandEnvironmentStrings(
    L"%CommonProgramFiles%\\microsoft shared\\ink\\TabTip.exe", path, MAX_PATH);
  if (expanded > 0 && expanded < MAX_PATH) {
    HINSTANCE result = ShellExecute(nullptr, L"open", path, nullptr, nullptr, SW_HIDE);
    return ((INT_PTR)result > 32) ? 1 : -1;
  }
  return -1;
}

extern "C" __declspec(dllexport) void SetTouchKeyboardVisible(bool visible) {
  if (!EnsureComApartment()) {
    return;
  }

  // P0: Before showing, ensure TabTip/TextInputHost is alive. Recover if not.
  if (visible) {
    EnsureTabTipHealthy(); // no-op if alive, launches TabTip if dead
  }

  static ULONGLONG last_toggle = 0;
  ULONGLONG now = GetTickCount64();
  
  bool current = IsKeyboardVisible();

  // If we are within the 300ms cooldown, strictly ignore any toggle attempts
  // to let the OS keyboard settle and prevent race/jitter/flickering.
  if (now - last_toggle < 300) {
    return;
  }

  // If the current physical state already matches the desired state, do nothing.
  if (visible == current) {
    g_osk_open_by_us = visible;
    return;
  }

  // Desired state differs from physical state, and cooldown has passed.
  // Toggle the keyboard.
  last_toggle = now;
  g_osk_open_by_us = visible;
  InvokeTipToggle();
}

extern "C" __declspec(dllexport) void SetTouchToMouseEnabled(bool enabled) {
  // Deprecated: touch-to-mouse translation is disabled. Native touch is used on all pages.
}

extern "C" __declspec(dllexport) bool GetLastInputWasTouch() {
  // Deprecated: pure native touch mode is active.
  return false;
}

extern "C" __declspec(dllexport) void SetOskOpenedByUs(bool opened) {
  g_osk_open_by_us = opened;
}

extern "C" __declspec(dllexport) bool GetOskOpenedByUs() {
  return g_osk_open_by_us;
}

extern "C" __declspec(dllexport) bool IsTouchKeyboardVisible() {
  return IsKeyboardVisible();
}

// P2: Expose both detection methods separately for Dart-side logging comparison
extern "C" __declspec(dllexport) bool IsTouchKeyboardVisibleMethodA() {
  return IsKeyboardVisibleMethodA();
}

extern "C" __declspec(dllexport) bool IsTouchKeyboardVisibleMethodB() {
  return IsKeyboardVisibleMethodB();
}

extern "C" __declspec(dllexport) bool IsTouchKeyboardVisibleMethodC() {
  return IsOskVisibleViaInputPane();
}

extern "C" __declspec(dllexport) bool IsSlateMode() {
  // SM_CONVERTIBLESLATEMODE = 0x2003
  // Returns 0 in Slate Mode (tablet), non-zero in Laptop/Desktop Mode
  return GetSystemMetrics(0x2003) == 0;
}

extern "C" __declspec(dllexport) bool IsSystemDocked() {
  // SM_SYSTEMDOCKED = 0x2004
  // Returns non-zero if docked, 0 if undocked
  return GetSystemMetrics(0x2004) != 0;
}

// P0: Health check exports - no admin required for query/process check
extern "C" __declspec(dllexport) bool IsTabTipProcessAliveExport() {
  return IsTabTipProcessAlive();
}

extern "C" __declspec(dllexport) bool IsTabletServiceRunningExport() {
  return IsTabletServiceRunning();
}

// Returns: 0=was alive, 1=relaunched OK, -1=relaunch failed
extern "C" __declspec(dllexport) int EnsureTabTipHealthyExport() {
  return EnsureTabTipHealthy();
}

// Enumerate ALL visible top-level windows - returns newline-separated "class|title|WxH"
// Used to discover what window class/title the OSK creates on this Windows version
struct EnumWindowsData {
  std::vector<std::string> results;
};

static BOOL CALLBACK EnumWindowsProc(HWND hwnd, LPARAM lParam) {
  if (!IsWindowVisible(hwnd)) return TRUE;
  RECT rect = {};
  GetWindowRect(hwnd, &rect);
  int w = rect.right - rect.left;
  int h = rect.bottom - rect.top;
  if (w < 10 || h < 10) return TRUE; // skip tiny/zero windows

  wchar_t className[256] = {};
  wchar_t title[512] = {};
  GetClassName(hwnd, className, 256);
  GetWindowText(hwnd, title, 512);

  // Convert to UTF-8 for Dart
  char classBuf[512] = {};
  char titleBuf[1024] = {};
  char dimBuf[64] = {};
  WideCharToMultiByte(CP_UTF8, 0, className, -1, classBuf, 512, nullptr, nullptr);
  WideCharToMultiByte(CP_UTF8, 0, title, -1, titleBuf, 1024, nullptr, nullptr);
  sprintf_s(dimBuf, "%dx%d", w, h);

  std::string entry = std::string(classBuf) + "|" + std::string(titleBuf) + "|" + std::string(dimBuf);
  EnumWindowsData* data = reinterpret_cast<EnumWindowsData*>(lParam);
  data->results.push_back(entry);
  return TRUE;
}

// Returns heap-allocated newline-delimited string. Caller must free with FreeEnumResult.
extern "C" __declspec(dllexport) char* EnumAllVisibleWindows() {
  EnumWindowsData data;
  EnumWindows(EnumWindowsProc, reinterpret_cast<LPARAM>(&data));
  
  std::string combined;
  for (const auto& s : data.results) {
    combined += s + "\n";
  }
  
  char* result = new char[combined.size() + 1];
  strcpy_s(result, combined.size() + 1, combined.c_str());
  return result;
}

extern "C" __declspec(dllexport) void FreeEnumResult(char* ptr) {
  delete[] ptr;
}

extern "C" __declspec(dllexport) bool IsClassVisible(const char* className) {
  if (className == nullptr) return false;
  int len = MultiByteToWideChar(CP_UTF8, 0, className, -1, nullptr, 0);
  if (len <= 0) return false;
  std::vector<wchar_t> wClassName(len);
  MultiByteToWideChar(CP_UTF8, 0, className, -1, wClassName.data(), len);

  HWND hwnd = FindWindow(wClassName.data(), nullptr);
  return IsWindowReallyVisible(hwnd);
}

extern "C" __declspec(dllexport) bool IsTitleVisible(const char* windowTitle) {
  if (windowTitle == nullptr) return false;
  int len = MultiByteToWideChar(CP_UTF8, 0, windowTitle, -1, nullptr, 0);
  if (len <= 0) return false;
  std::vector<wchar_t> wTitle(len);
  MultiByteToWideChar(CP_UTF8, 0, windowTitle, -1, wTitle.data(), len);

  HWND hwnd = FindWindow(nullptr, wTitle.data());
  return IsWindowReallyVisible(hwnd);
}

extern "C" __declspec(dllexport) bool IsOskVisibleViaInputPane() {
  IFrameworkInputPane* pInputPane = nullptr;
  HRESULT hr = CoCreateInstance(CLSID_FrameworkInputPane, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&pInputPane));
  bool com_initialized_by_us = false;
  if (hr == CO_E_NOTINITIALIZED) {
    hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (SUCCEEDED(hr)) {
      com_initialized_by_us = true;
      hr = CoCreateInstance(CLSID_FrameworkInputPane, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&pInputPane));
    }
  }

  bool visible = false;
  if (SUCCEEDED(hr) && pInputPane != nullptr) {
    RECT rcLocation = { 0 };
    hr = pInputPane->Location(&rcLocation);
    if (SUCCEEDED(hr)) {
      if (!(rcLocation.bottom == 0 && rcLocation.left == 0 && 
            rcLocation.right == 0 && rcLocation.top == 0)) {
        visible = true;
      }
    }
    pInputPane->Release();
  }

  if (com_initialized_by_us) {
    CoUninitialize();
  }
  return visible;
}

extern "C" __declspec(dllexport) void CloseWindowByClass(const char* className) {
  if (className == nullptr) return;
  int len = MultiByteToWideChar(CP_UTF8, 0, className, -1, nullptr, 0);
  if (len <= 0) return;
  std::vector<wchar_t> wClassName(len);
  MultiByteToWideChar(CP_UTF8, 0, className, -1, wClassName.data(), len);

  HWND hwnd = FindWindow(wClassName.data(), nullptr);
  if (hwnd != nullptr) {
    PostMessage(hwnd, WM_SYSCOMMAND, SC_CLOSE, 0);
    ShowWindow(hwnd, SW_HIDE);
  }
}

extern "C" __declspec(dllexport) void CloseWindowByTitle(const char* windowTitle) {
  if (windowTitle == nullptr) return;
  int len = MultiByteToWideChar(CP_UTF8, 0, windowTitle, -1, nullptr, 0);
  if (len <= 0) return;
  std::vector<wchar_t> wTitle(len);
  MultiByteToWideChar(CP_UTF8, 0, windowTitle, -1, wTitle.data(), len);

  HWND hwnd = FindWindow(nullptr, wTitle.data());
  if (hwnd != nullptr) {
    PostMessage(hwnd, WM_SYSCOMMAND, SC_CLOSE, 0);
    ShowWindow(hwnd, SW_HIDE);
  }
}

extern "C" __declspec(dllexport) void LaunchTabTipProcess() {
  wchar_t path[MAX_PATH];
  DWORD expanded = ExpandEnvironmentStrings(L"%CommonProgramFiles%\\microsoft shared\\ink\\TabTip.exe", path, MAX_PATH);
  if (expanded > 0 && expanded < MAX_PATH) {
    ShellExecute(nullptr, L"open", path, nullptr, nullptr, SW_SHOW);
  } else {
    ShellExecute(nullptr, L"open", L"C:\\Program Files\\Common Files\\microsoft shared\\ink\\TabTip.exe", nullptr, nullptr, SW_SHOW);
  }
}

namespace windows_osk_guard {

// static
void WindowsOskGuardPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "windows_osk_guard",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<WindowsOskGuardPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  // Automatically fetch view handle
  HWND child_hwnd = registrar->GetView()->GetNativeWindow();
  g_child_window_handle = child_hwnd;
  g_main_window_handle = GetAncestor(child_hwnd, GA_ROOT);

  registrar->AddPlugin(std::move(plugin));
}

WindowsOskGuardPlugin::WindowsOskGuardPlugin() {}

WindowsOskGuardPlugin::~WindowsOskGuardPlugin() {}

void WindowsOskGuardPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

}  // namespace windows_osk_guard
