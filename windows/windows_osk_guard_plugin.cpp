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
#pragma comment(lib, "comctl32.lib")

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

// Define COM GUIDs for touch keyboard invocation
// {4CE576FA-83DC-4F88-951C-9D0782B4E376}
DEFINE_GUID(CLSID_UIHostNoLaunch, 0x4ce576fa, 0x83dc, 0x4f88, 0x95, 0x1c, 0x9d, 0x07, 0x82, 0xb4, 0xe3, 0x76);

// {37C994E7-432B-4834-A2F7-DCE1F13B834B}
DEFINE_GUID(IID_ITipInvocation, 0x37c994e7, 0x432b, 0x4834, 0xa2, 0xf7, 0xdc, 0xe1, 0xf1, 0x3b, 0x83, 0x4b);

struct ITipInvocation : IUnknown {
  virtual HRESULT STDMETHODCALLTYPE Toggle(HWND hwnd) = 0;
};

static bool g_touch_to_mouse_enabled = true;
static bool g_last_input_was_touch = false;
static HWND g_main_window_handle = nullptr;
static POINT g_start_pt = { 0, 0 };
static bool g_is_dragging = false;
static DWORD g_down_time = 0;

static bool IsWindowReallyVisible(HWND hwnd) {
  if (hwnd == nullptr) return false;
  if (!IsWindowVisible(hwnd)) return false;
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

static bool IsKeyboardVisible() {
  HWND hwnd10 = FindWindow(L"IPTIP_Main_Window", nullptr);
  if (IsWindowReallyVisible(hwnd10)) return true;

  HWND hwnd11 = FindWindow(nullptr, L"Microsoft Text Input Application");
  if (IsWindowReallyVisible(hwnd11)) return true;

  HWND hwndAlt = FindWindow(nullptr, L"Windows Input Experience");
  if (IsWindowReallyVisible(hwndAlt)) return true;

  return false;
}

extern "C" __declspec(dllexport) void SetTouchKeyboardVisible(bool visible) {
  bool current = IsKeyboardVisible();
  if (visible) {
    if (!current) {
      ITipInvocation* pTipInvocation = nullptr;
      HRESULT hr = CoCreateInstance(CLSID_UIHostNoLaunch, nullptr, 
                                    CLSCTX_INPROC_HANDLER | CLSCTX_LOCAL_SERVER, 
                                    IID_ITipInvocation, (void**)&pTipInvocation);
      if (SUCCEEDED(hr)) {
        HWND target_hwnd = g_main_window_handle;
        if (target_hwnd == nullptr) {
          target_hwnd = GetActiveWindow();
        }
        if (target_hwnd == nullptr) {
          target_hwnd = GetDesktopWindow();
        }
        pTipInvocation->Toggle(target_hwnd);
        pTipInvocation->Release();
      }
    }
  } else {
    // Hide keyboard by sending SC_CLOSE to visible windows
    HWND hwnd11 = FindWindow(nullptr, L"Microsoft Text Input Application");
    if (hwnd11 != nullptr && IsWindowVisible(hwnd11)) {
      PostMessage(hwnd11, 0x0112, 0xF060, 0); // WM_SYSCOMMAND, SC_CLOSE
      ShowWindow(hwnd11, SW_HIDE);
    }
    HWND hwndAlt = FindWindow(nullptr, L"Windows Input Experience");
    if (hwndAlt != nullptr && IsWindowVisible(hwndAlt)) {
      PostMessage(hwndAlt, 0x0112, 0xF060, 0); // WM_SYSCOMMAND, SC_CLOSE
      ShowWindow(hwndAlt, SW_HIDE);
    }
  }
}

extern "C" __declspec(dllexport) void SetTouchToMouseEnabled(bool enabled) {
  g_touch_to_mouse_enabled = enabled;
}

extern "C" __declspec(dllexport) bool GetLastInputWasTouch() {
  return g_last_input_was_touch;
}

extern "C" __declspec(dllexport) bool IsTouchKeyboardVisible() {
  return IsKeyboardVisible();
}

// Subclass procedure to intercept touch messages at the child window level.
// This translates OS touch inputs to standard mouse inputs and suppresses the original
// touch events, preventing Windows from triggering the touch keyboard automatically.
static LRESULT CALLBACK FlutterViewSubclassProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam, UINT_PTR uIdSubclass, DWORD_PTR dwRefData) {
  // Capture mouse down messages and check if they originate from touch/pen.
  if (uMsg == WM_LBUTTONDOWN || uMsg == WM_RBUTTONDOWN || uMsg == WM_MBUTTONDOWN) {
    LPARAM extra = GetMessageExtraInfo();
    if ((extra & 0xFFFFFF00) == 0xFF515700) {
      g_last_input_was_touch = true;
    } else {
      g_last_input_was_touch = false;
    }
  }

  if (g_touch_to_mouse_enabled) {
    if (uMsg == WM_TOUCH) {
      g_last_input_was_touch = true;
      UINT cInputs = LOWORD(wParam);
      HTOUCHINPUT hTouchInput = reinterpret_cast<HTOUCHINPUT>(lParam);
      if (cInputs > 0) {
        TOUCHINPUT* pInputs = new TOUCHINPUT[cInputs];
        if (GetTouchInputInfo(hTouchInput, cInputs, pInputs, sizeof(TOUCHINPUT))) {
          // If there is more than 1 touch contact, let it pass through to the default windows proc
          // so that multi-touch gestures (like pinch-to-zoom) are preserved!
          if (cInputs > 1) {
            CloseTouchInputHandle(hTouchInput);
            delete[] pInputs;
            return DefSubclassProc(hWnd, uMsg, wParam, lParam);
          }

          POINT pt = { pInputs[0].x / 100, pInputs[0].y / 100 };
          ScreenToClient(hWnd, &pt);

          UINT mouseMsg = 0;
          WPARAM mouseWparam = 0;
          LPARAM mouseLparam = MAKELPARAM(pt.x, pt.y);

          if (pInputs[0].dwFlags & TOUCHEVENTF_DOWN) {
            g_start_pt = pt;
            g_down_time = GetTickCount();
            g_is_dragging = false;
            mouseMsg = WM_LBUTTONDOWN;
            mouseWparam = MK_LBUTTON;
            SetCapture(hWnd);
          } else if (pInputs[0].dwFlags & TOUCHEVENTF_UP) {
            DWORD duration = GetTickCount() - g_down_time;
            int dx = pt.x - g_start_pt.x;
            int dy = pt.y - g_start_pt.y;
            if (duration >= 500 && (dx * dx + dy * dy < 144)) {
              DefSubclassProc(hWnd, WM_RBUTTONDOWN, MK_RBUTTON, MAKELPARAM(pt.x, pt.y));
              DefSubclassProc(hWnd, WM_RBUTTONUP, 0, MAKELPARAM(pt.x, pt.y));
              ReleaseCapture();
              CloseTouchInputHandle(hTouchInput);
              delete[] pInputs;
              return 0;
            }
            mouseMsg = WM_LBUTTONUP;
            mouseWparam = 0;
            ReleaseCapture();
          } else if (pInputs[0].dwFlags & TOUCHEVENTF_MOVE) {
            if (g_is_dragging) {
              mouseMsg = WM_MOUSEMOVE;
              mouseWparam = MK_LBUTTON;
            } else {
              int dx = pt.x - g_start_pt.x;
              int dy = pt.y - g_start_pt.y;
              if (dx * dx + dy * dy >= 144) { // 12 pixels slop
                g_is_dragging = true;
                mouseMsg = WM_MOUSEMOVE;
                mouseWparam = MK_LBUTTON;
              }
            }
          }

          if (mouseMsg != 0) {
            DefSubclassProc(hWnd, mouseMsg, mouseWparam, mouseLparam);
          }
          CloseTouchInputHandle(hTouchInput);
          delete[] pInputs;
          return 0; // prevent default OS touch processing and OSK
        }
        delete[] pInputs;
      }
      CloseTouchInputHandle(hTouchInput);
      return 0;
    }
    else if (uMsg >= WM_POINTERFIRST && uMsg <= WM_POINTERLAST) {
      UINT32 pointerId = LOWORD(wParam);
      POINTER_INPUT_TYPE pointerType = PT_POINTER;
      if (GetPointerType(pointerId, &pointerType)) {
        if (pointerType == PT_TOUCH || pointerType == PT_PEN) {
          POINTER_INFO pointerInfo{};
          if (GetPointerInfo(pointerId, &pointerInfo)) {
            // Let non-primary pointers pass through to preserve multi-touch pinch/zoom
            if (!(pointerInfo.pointerFlags & POINTER_FLAG_PRIMARY)) {
              return DefSubclassProc(hWnd, uMsg, wParam, lParam);
            }
          }

          if (uMsg == WM_POINTERDOWN) {
            g_last_input_was_touch = true;
          }
          POINT pt = { (long)(short)LOWORD(lParam), (long)(short)HIWORD(lParam) };
          ScreenToClient(hWnd, &pt);

          UINT mouseMsg = 0;
          WPARAM mouseWparam = 0;
          LPARAM mouseLparam = MAKELPARAM(pt.x, pt.y);

          if (uMsg == WM_POINTERDOWN) {
            g_start_pt = pt;
            g_down_time = GetTickCount();
            g_is_dragging = false;
            mouseMsg = WM_LBUTTONDOWN;
            mouseWparam = MK_LBUTTON;
            SetCapture(hWnd);
          } else if (uMsg == WM_POINTERUP) {
            DWORD duration = GetTickCount() - g_down_time;
            int dx = pt.x - g_start_pt.x;
            int dy = pt.y - g_start_pt.y;
            if (duration >= 500 && (dx * dx + dy * dy < 144)) {
              DefSubclassProc(hWnd, WM_RBUTTONDOWN, MK_RBUTTON, MAKELPARAM(pt.x, pt.y));
              DefSubclassProc(hWnd, WM_RBUTTONUP, 0, MAKELPARAM(pt.x, pt.y));
              ReleaseCapture();
              return 0;
            }
            mouseMsg = WM_LBUTTONUP;
            mouseWparam = 0;
            ReleaseCapture();
          } else if (uMsg == WM_POINTERUPDATE) {
            if (g_is_dragging) {
              mouseMsg = WM_MOUSEMOVE;
              if (pointerInfo.pointerFlags & POINTER_FLAG_DOWN) {
                mouseWparam = MK_LBUTTON;
              }
            } else {
              int dx = pt.x - g_start_pt.x;
              int dy = pt.y - g_start_pt.y;
              if (dx * dx + dy * dy >= 144) { // 12 pixels slop
                g_is_dragging = true;
                mouseMsg = WM_MOUSEMOVE;
                if (pointerInfo.pointerFlags & POINTER_FLAG_DOWN) {
                  mouseWparam = MK_LBUTTON;
                }
              }
            }
          }

          if (mouseMsg != 0) {
            DefSubclassProc(hWnd, mouseMsg, mouseWparam, mouseLparam);
          }
          return 0; // prevent default OS pointer processing and OSK
        }
        else if (pointerType == PT_MOUSE) {
          if (uMsg == WM_POINTERDOWN) {
            g_last_input_was_touch = false;
          }
        }
      }
    }
  }
  return DefSubclassProc(hWnd, uMsg, wParam, lParam);
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

  // Automatically fetch view handle and attach subclass procedure to child window
  HWND child_hwnd = registrar->GetView()->GetNativeWindow();
  g_main_window_handle = GetAncestor(child_hwnd, GA_ROOT);
  SetWindowSubclass(child_hwnd, FlutterViewSubclassProc, 1, 0);

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
