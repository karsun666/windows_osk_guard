import 'dart:async';
import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'windows_osk_guard_platform_interface.dart';

typedef SetTouchKeyboardVisibleNative = Void Function(Bool visible);
typedef SetTouchKeyboardVisibleDart = void Function(bool visible);

typedef SetTouchToMouseEnabledNative = Void Function(Bool enabled);
typedef SetTouchToMouseEnabledDart = void Function(bool enabled);

typedef GetLastInputWasTouchNative = Bool Function();
typedef GetLastInputWasTouchDart = bool Function();

typedef SetOskOpenedByUsNative = Void Function(Bool opened);
typedef SetOskOpenedByUsDart = void Function(bool opened);

typedef GetOskOpenedByUsNative = Bool Function();
typedef GetOskOpenedByUsDart = bool Function();

typedef IsTouchKeyboardVisibleNative = Bool Function();
typedef IsTouchKeyboardVisibleDart = bool Function();

typedef IsSlateModeNative = Bool Function();
typedef IsSlateModeDart = bool Function();

typedef IsSystemDockedNative = Bool Function();
typedef IsSystemDockedDart = bool Function();

/// Stub class to satisfy default Flutter project template files and tests.
class WindowsOskGuard {
  Future<String?> getPlatformVersion() {
    return WindowsOskGuardPlatform.instance.getPlatformVersion();
  }
}

/// A FFI bridge that binds to the native Windows C++ DLL to control the virtual keyboard.
class TouchBridge {
  static DynamicLibrary? _dylib;
  static bool _initialized = false;
  static String? _lastInitError;
  static SetTouchKeyboardVisibleDart? _setTouchKeyboardVisible;
  static SetTouchToMouseEnabledDart? _setTouchToMouseEnabled;
  static GetLastInputWasTouchDart? _getLastInputWasTouch;
  static SetOskOpenedByUsDart? _setOskOpenedByUs;
  static GetOskOpenedByUsDart? _getOskOpenedByUs;
  static IsTouchKeyboardVisibleDart? _isTouchKeyboardVisible;
  static IsSlateModeDart? _isSlateMode;
  static IsSystemDockedDart? _isSystemDocked;

  static bool get isReady => _initialized && _setTouchKeyboardVisible != null;

  static String? get lastInitError => _lastInitError;

  static String _pluginDllPath() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir${Platform.pathSeparator}windows_osk_guard_plugin.dll';
  }

  static DynamicLibrary? _openPluginLibrary() {
    final candidates = <String>[
      _pluginDllPath(),
      'windows_osk_guard_plugin.dll',
    ];
    Object? lastError;
    for (final path in candidates) {
      try {
        return DynamicLibrary.open(path);
      } catch (e) {
        lastError = e;
      }
    }
    _lastInitError = lastError?.toString();
    return null;
  }

  static bool init({bool enableTouchToMouse = false}) {
    if (_initialized) return isReady;
    if (!Platform.isWindows) {
      _lastInitError = 'Not running on Windows';
      return false;
    }
    try {
      _dylib = _openPluginLibrary();
      if (_dylib == null) {
        debugPrint('[TouchBridge] Failed to load native DLL: $_lastInitError');
        return false;
      }

      _setTouchKeyboardVisible = _dylib!
          .lookupFunction<SetTouchKeyboardVisibleNative, SetTouchKeyboardVisibleDart>(
              'SetTouchKeyboardVisible');

      _setTouchToMouseEnabled = _dylib!
          .lookupFunction<SetTouchToMouseEnabledNative, SetTouchToMouseEnabledDart>(
              'SetTouchToMouseEnabled');

      _getLastInputWasTouch = _dylib!
          .lookupFunction<GetLastInputWasTouchNative, GetLastInputWasTouchDart>(
              'GetLastInputWasTouch');

      _setOskOpenedByUs = _dylib!
          .lookupFunction<SetOskOpenedByUsNative, SetOskOpenedByUsDart>(
              'SetOskOpenedByUs');

      _getOskOpenedByUs = _dylib!
          .lookupFunction<GetOskOpenedByUsNative, GetOskOpenedByUsDart>(
              'GetOskOpenedByUs');

      _isTouchKeyboardVisible = _dylib!
          .lookupFunction<IsTouchKeyboardVisibleNative, IsTouchKeyboardVisibleDart>(
              'IsTouchKeyboardVisible');

      _isSlateMode = _dylib!
          .lookupFunction<IsSlateModeNative, IsSlateModeDart>(
              'IsSlateMode');

      _isSystemDocked = _dylib!
          .lookupFunction<IsSystemDockedNative, IsSystemDockedDart>(
              'IsSystemDocked');

      _initialized = true;
      _lastInitError = null;
      debugPrint('[TouchBridge] Successfully bound native touch bridge DLL functions.');
      if (enableTouchToMouse) {
        setToMouseEnabled(true);
      }
      return true;
    } catch (e) {
      _lastInitError = e.toString();
      debugPrint('[TouchBridge] Failed to load native touch bridge functions: $e');
      return false;
    }
  }

  static void setKeyboardVisible(bool visible) {
    if (_setTouchKeyboardVisible != null) {
      try {
        _setTouchKeyboardVisible!(visible);
        debugPrint('[TouchBridge] Set touch keyboard visibility to: $visible');
      } catch (e) {
        debugPrint('[TouchBridge] Error calling SetTouchKeyboardVisible: $e');
      }
    } else {
      if (!visible) {
        OskWindowMonitor.hideKeyboard();
      }
    }
  }

  static void setToMouseEnabled(bool enabled) {
    if (_setTouchToMouseEnabled != null) {
      try {
        _setTouchToMouseEnabled!(enabled);
        debugPrint('[TouchBridge] Set touch-to-mouse translation to: $enabled');
      } catch (e) {
        debugPrint('[TouchBridge] Error calling SetTouchToMouseEnabled: $e');
      }
    }
  }

  static bool getLastInputWasTouch() {
    if (_getLastInputWasTouch != null) {
      try {
        return _getLastInputWasTouch!();
      } catch (e) {
        debugPrint('[TouchBridge] Error calling GetLastInputWasTouch: $e');
      }
    }
    return false;
  }

  static void setOskOpenedByUs(bool opened) {
    if (_setOskOpenedByUs != null) {
      try {
        _setOskOpenedByUs!(opened);
        debugPrint('[TouchBridge] Set OSK opened by us: $opened');
      } catch (e) {
        debugPrint('[TouchBridge] Error calling SetOskOpenedByUs: $e');
      }
    }
  }

  static bool getOskOpenedByUs() {
    if (_getOskOpenedByUs != null) {
      try {
        return _getOskOpenedByUs!();
      } catch (e) {
        debugPrint('[TouchBridge] Error calling GetOskOpenedByUs: $e');
      }
    }
    return false;
  }

  static bool isTouchKeyboardVisible() {
    if (_isTouchKeyboardVisible != null) {
      try {
        return _isTouchKeyboardVisible!();
      } catch (e) {
        debugPrint('[TouchBridge] Error calling IsTouchKeyboardVisible: $e');
      }
    }
    return false;
  }

  static bool isSlateMode() {
    if (_isSlateMode != null) {
      try {
        return _isSlateMode!();
      } catch (e) {
        debugPrint('[TouchBridge] Error calling IsSlateMode: $e');
      }
    }
    return false;
  }

  static bool isSystemDocked() {
    if (_isSystemDocked != null) {
      try {
        return _isSystemDocked!();
      } catch (e) {
        debugPrint('[TouchBridge] Error calling IsSystemDocked: $e');
      }
    }
    return false;
  }
}

/// Real-time monitor for the Windows touch keyboard window visibility.
class OskWindowMonitor {
  OskWindowMonitor({this.intervalMs = 100, this.onAppeared});
  final int intervalMs;
  final VoidCallback? onAppeared;
  Timer? _timer;
  bool _wasVisible = false;

  void start() {
    if (!Platform.isWindows) return;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      bool current = isKeyboardWindowVisible();
      if (current && !_wasVisible) {
        _wasVisible = true;
        if (onAppeared != null) onAppeared!();
      } else if (!current && _wasVisible) {
        _wasVisible = false;
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static bool isKeyboardWindowVisible() {
    if (Platform.isWindows) {
      return TouchBridge.isTouchKeyboardVisible();
    }
    return false;
  }

  static void hideKeyboard() {
    if (Platform.isWindows) {
      TouchBridge.setKeyboardVisible(false);
    }
  }
}

/// A global widget that intercept touch events and controls the Windows virtual keyboard.
class GlobalTouchKeyboardGuard extends StatefulWidget {
  const GlobalTouchKeyboardGuard({super.key, required this.child});
  final Widget child;

  static final GlobalKey<GlobalTouchKeyboardGuardState> globalKey =
      GlobalKey<GlobalTouchKeyboardGuardState>();

  @override
  State<GlobalTouchKeyboardGuard> createState() => GlobalTouchKeyboardGuardState();
}

class GlobalTouchKeyboardGuardState extends State<GlobalTouchKeyboardGuard> {
  late final OskWindowMonitor _oskMonitor;
  bool _lastTapWasTextField = false;

  @override
  void initState() {
    super.initState();
    TouchBridge.init();
    
    // Listen to focus changes to dynamically toggle touch-to-mouse emulation (autocorrect fix)
    FocusManager.instance.addListener(_handleFocusChange);
    
    _oskMonitor = OskWindowMonitor(
      intervalMs: 80,
      onAppeared: () {
        if (Platform.isWindows) {
          final primary = FocusManager.instance.primaryFocus;
          final isTextFocused = primary != null && _focusIsEditable(primary);
          debugPrint('⌨️ [OSK MONITOR] Keyboard appeared. Focus is in Text Field: $isTextFocused');
          if (!isTextFocused) {
            debugPrint('👉 [OSK MONITOR] Suppressing unexpected keyboard window appearance because focus is not in editable field.');
            TouchBridge.setKeyboardVisible(false);
          }
        }
      },
    );
    _oskMonitor.start();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    _oskMonitor.stop();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!Platform.isWindows) return;
    final primary = FocusManager.instance.primaryFocus;
    final isTextFocused = primary != null && _focusIsEditable(primary);
    
    // Disable touch-to-mouse translation when typing, to restore native touch typing/autocorrect
    if (isTextFocused) {
      debugPrint('[OSK Guard] Focus shifted to editable field. Disabling touch-to-mouse translation.');
      TouchBridge.setToMouseEnabled(false);
    } else {
      debugPrint('[OSK Guard] Focus cleared from editable field. Re-enabling touch-to-mouse translation.');
      TouchBridge.setToMouseEnabled(true);
    }
  }

  void forceSuppressKeyboard() {
    if (Platform.isWindows) {
      _lastTapWasTextField = false;
      TouchBridge.setKeyboardVisible(false);
    }
  }

  static bool _focusIsEditable(FocusNode node) {
    if (node.context?.widget is EditableText) {
      return true;
    }
    bool isEditable = false;
    node.context?.visitAncestorElements((element) {
      final name = element.widget.runtimeType.toString();
      if (name == 'TextField' || name == 'TextFormField' || name == 'EditableText') {
        isEditable = true;
        return false;
      }
      return true;
    });
    return isEditable;
  }

  static bool _hitTestIncludesEditable(BuildContext context, PointerDownEvent event) {
    final view = View.maybeOf(context);
    if (view == null) return false;
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, view.viewId);
    for (final entry in result.path) {
      if (entry.target is RenderEditable) {
        return true;
      }
    }
    return false;
  }

  static List<String> _getTappedWidgetTypes(BuildContext context, PointerDownEvent event) {
    final view = View.maybeOf(context);
    if (view == null) return [];
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, view.viewId);
    final Set<String> types = {};
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderObject) {
        try {
          final dynamic creator = (target as dynamic).debugCreator;
          if (creator != null) {
            final dynamic element = creator.element;
            if (element != null) {
              types.add(element.widget.runtimeType.toString());
            }
          }
        } catch (_) {}
      }
    }
    return types.toList();
  }

  void _onPointerDown(BuildContext context, PointerDownEvent event) {
    final isTextFieldTapped = _hitTestIncludesEditable(context, event);
    bool isTextWidgetInStack = false;

    if (kDebugMode) {
      final tappedWidgets = _getTappedWidgetTypes(context, event);
      isTextWidgetInStack = tappedWidgets.any((w) =>
          w == 'TextFieldTapRegion' ||
          w == 'EditableText' ||
          w == 'TextField' ||
          w == 'TextFormField');
      debugPrint('[OSK Guard] Tap detected - Hit-test editable: $isTextFieldTapped | Stack editable: $isTextWidgetInStack');
    }

    final isTextField = isTextFieldTapped || isTextWidgetInStack;

    if (isTextField) {
      if (Platform.isWindows) {
        // P1 FIX: Use event.kind directly from Flutter's PointerDownEvent.
        // GetLastInputWasTouch() was dead code (always returned false).
        // event.kind is set by Flutter's Windows embedder based on the actual
        // WM_POINTER message type - reliable without any native C++ stub.
        final isTouch = event.kind == PointerDeviceKind.touch ||
                        event.kind == PointerDeviceKind.stylus;
        debugPrint('[OSK Guard] TextField tap - input kind: ${event.kind.name}, isTouch: $isTouch');
        if (isTouch) {
          _lastTapWasTextField = true;
          TouchBridge.setOskOpenedByUs(true);
          // Delay slightly to allow Flutter to focus the field first,
          // then check if Windows already opened OSK; if not, open it ourselves.
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted && _lastTapWasTextField) {
              final isAlreadyVisible = OskWindowMonitor.isKeyboardWindowVisible();
              if (!isAlreadyVisible) {
                debugPrint('[OSK Guard] Windows did NOT auto-open OSK — opening via COM Toggle.');
                TouchBridge.setKeyboardVisible(true);
              } else {
                debugPrint('[OSK Guard] Windows already opened OSK — no action needed.');
              }
            }
          });
        } else {
          // Mouse/trackpad tap on TextField — do NOT open OSK
          _lastTapWasTextField = false;
          debugPrint('[OSK Guard] TextField tap via mouse/trackpad — OSK suppressed.');
        }
      } else {
        _lastTapWasTextField = true;
      }
      return;
    }


    final primary = FocusManager.instance.primaryFocus;
    final isTextFocused = primary != null && _focusIsEditable(primary);

    if (isTextFocused) {
      primary.unfocus();
    }

    if (Platform.isWindows) {
      _lastTapWasTextField = false;
      TouchBridge.setOskOpenedByUs(false);
      TouchBridge.setKeyboardVisible(false);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_lastTapWasTextField) {
          TouchBridge.setKeyboardVisible(false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _onPointerDown(context, e),
      child: widget.child,
    );
  }
}

/// Suppresses the Windows touch keyboard during Navigator page transitions.
class KeyboardSuppressingNavigatorObserver extends NavigatorObserver {
  void _suppress() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (Platform.isWindows) {
      GlobalTouchKeyboardGuard.globalKey.currentState?.forceSuppressKeyboard();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _suppress();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _suppress();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is PageRoute) _suppress();
  }
}
