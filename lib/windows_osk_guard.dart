import 'dart:async';
import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:windows_osk_guard/windows_osk_guard_platform_interface.dart';

typedef SetTouchKeyboardVisibleNative = Void Function(Bool visible);
typedef SetTouchKeyboardVisibleDart = void Function(bool visible);

typedef SetTouchToMouseEnabledNative = Void Function(Bool enabled);
typedef SetTouchToMouseEnabledDart = void Function(bool enabled);

typedef GetLastInputWasTouchNative = Bool Function();
typedef GetLastInputWasTouchDart = bool Function();

typedef IsTouchKeyboardVisibleNative = Bool Function();
typedef IsTouchKeyboardVisibleDart = bool Function();

/// Stub class to satisfy default Flutter project template files and tests.
class WindowsOskGuard {
  Future<String?> getPlatformVersion() {
    return WindowsOskGuardPlatform.instance.getPlatformVersion();
  }
}

/// A FFI bridge that binds to the native Windows C++ DLL to control the virtual keyboard.
class TouchBridge {
  static DynamicLibrary? _dylib;
  static SetTouchKeyboardVisibleDart? _setTouchKeyboardVisible;
  static SetTouchToMouseEnabledDart? _setTouchToMouseEnabled;
  static GetLastInputWasTouchDart? _getLastInputWasTouch;
  static IsTouchKeyboardVisibleDart? _isTouchKeyboardVisible;

  static void init() {
    if (!Platform.isWindows) return;
    try {
      _dylib = DynamicLibrary.open('windows_osk_guard_plugin.dll');
      
      _setTouchKeyboardVisible = _dylib!
          .lookupFunction<SetTouchKeyboardVisibleNative, SetTouchKeyboardVisibleDart>(
              'SetTouchKeyboardVisible');

      _setTouchToMouseEnabled = _dylib!
          .lookupFunction<SetTouchToMouseEnabledNative, SetTouchToMouseEnabledDart>(
              'SetTouchToMouseEnabled');

      _getLastInputWasTouch = _dylib!
          .lookupFunction<GetLastInputWasTouchNative, GetLastInputWasTouchDart>(
              'GetLastInputWasTouch');

      _isTouchKeyboardVisible = _dylib!
          .lookupFunction<IsTouchKeyboardVisibleNative, IsTouchKeyboardVisibleDart>(
              'IsTouchKeyboardVisible');
              
      debugPrint('[TouchBridge] Successfully bound native touch bridge DLL functions.');
      
      setToMouseEnabled(true);
    } catch (e) {
      debugPrint('[TouchBridge] Failed to load native touch bridge functions: $e');
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

  static bool isKeyboardVisible() {
    if (_isTouchKeyboardVisible != null) {
      try {
        return _isTouchKeyboardVisible!();
      } catch (e) {
        debugPrint('[TouchBridge] Error calling IsTouchKeyboardVisible: $e');
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
    return TouchBridge.isKeyboardVisible();
  }

  static void hideKeyboard() {
    TouchBridge.setKeyboardVisible(false);
  }
}

/// A global widget that intercepts touch events and controls the Windows virtual keyboard.
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
  DateTime _lastTextFieldTapTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    TouchBridge.init();
    _oskMonitor = OskWindowMonitor(
      intervalMs: 80,
      onAppeared: () {
        final timeSinceTap = DateTime.now().difference(_lastTextFieldTapTime);
        if (timeSinceTap.inMilliseconds > 1500 && Platform.isWindows) {
          debugPrint('[OSK Guard] Suppressing unexpected keyboard window (time since tap: ${timeSinceTap.inMilliseconds}ms)');
          TouchBridge.setKeyboardVisible(false);
        }
      },
    );
    _oskMonitor.start();
  }

  @override
  void dispose() {
    _oskMonitor.stop();
    super.dispose();
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
        final isTouch = TouchBridge.getLastInputWasTouch();
        if (isTouch) {
          _lastTextFieldTapTime = DateTime.now();
          _lastTapWasTextField = true;
          TouchBridge.setKeyboardVisible(true);
        } else {
          _lastTapWasTextField = false;
        }
      } else {
        _lastTextFieldTapTime = DateTime.now();
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
