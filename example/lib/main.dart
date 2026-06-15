import 'package:flutter/material.dart';
import 'package:windows_osk_guard/windows_osk_guard.dart';
import 'dart:ffi';
import 'dart:async';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'native_dll.dart';

typedef IsClassVisibleNative = Bool Function(Pointer<Utf8> className);
typedef IsClassVisibleDart = bool Function(Pointer<Utf8> className);

typedef IsTitleVisibleNative = Bool Function(Pointer<Utf8> windowTitle);
typedef IsTitleVisibleDart = bool Function(Pointer<Utf8> windowTitle);

typedef IsOskVisibleViaInputPaneNative = Bool Function();
typedef IsOskVisibleViaInputPaneDart = bool Function();

typedef CloseWindowByClassNative = Void Function(Pointer<Utf8> className);
typedef CloseWindowByClassDart = void Function(Pointer<Utf8> className);

typedef CloseWindowByTitleNative = Void Function(Pointer<Utf8> windowTitle);
typedef CloseWindowByTitleDart = void Function(Pointer<Utf8> windowTitle);

typedef LaunchTabTipProcessNative = Void Function();
typedef LaunchTabTipProcessDart = void Function();

// P2: Window enumeration for OSK window discovery
typedef EnumAllVisibleWindowsNative = Pointer<Utf8> Function();
typedef EnumAllVisibleWindowsDart = Pointer<Utf8> Function();

typedef FreeEnumResultNative = Void Function(Pointer<Utf8> ptr);
typedef FreeEnumResultDart = void Function(Pointer<Utf8> ptr);

// P0: TabTip health check bindings
typedef IsTabTipProcessAliveNative = Bool Function();
typedef IsTabTipProcessAliveDart = bool Function();

typedef IsTabletServiceRunningNative = Bool Function();
typedef IsTabletServiceRunningDart = bool Function();

typedef EnsureTabTipHealthyNative = Int32 Function();
typedef EnsureTabTipHealthyDart = int Function();

// P2: Dual-method visibility bindings
typedef IsTouchKeyboardVisibleMethodANative = Bool Function();
typedef IsTouchKeyboardVisibleMethodADart = bool Function();

typedef IsTouchKeyboardVisibleMethodBNative = Bool Function();
typedef IsTouchKeyboardVisibleMethodBDart = bool Function();

typedef IsTouchKeyboardVisibleMethodCNative = Bool Function();
typedef IsTouchKeyboardVisibleMethodCDart = bool Function();

typedef IsSlateModeNative = Bool Function();
typedef IsSlateModeDart = bool Function();

typedef IsSystemDockedNative = Bool Function();
typedef IsSystemDockedDart = bool Function();

class DiagnosticBridge {
  static DynamicLibrary? _dylib;
  static IsClassVisibleDart? _isClassVisible;
  static IsTitleVisibleDart? _isTitleVisible;
  static IsOskVisibleViaInputPaneDart? _isOskVisibleViaInputPane;
  static CloseWindowByClassDart? _closeWindowByClass;
  static CloseWindowByTitleDart? _closeWindowByTitle;
  static LaunchTabTipProcessDart? _launchTabTipProcess;
  // P0: Health check
  static IsTabTipProcessAliveDart? _isTabTipProcessAlive;
  static IsTabletServiceRunningDart? _isTabletServiceRunning;
  static EnsureTabTipHealthyDart? _ensureTabTipHealthy;
  // P2: Dual-method detection
  static IsTouchKeyboardVisibleMethodADart? _isVisibleMethodA;
  static IsTouchKeyboardVisibleMethodBDart? _isVisibleMethodB;
  static IsTouchKeyboardVisibleMethodCDart? _isVisibleMethodC;
  static IsSlateModeDart? _isSlateMode;
  static IsSystemDockedDart? _isSystemDocked;
  // Window enumeration
  static EnumAllVisibleWindowsDart? _enumAllVisibleWindows;
  static FreeEnumResultDart? _freeEnumResult;

  static bool get isReady =>
      _isClassVisible != null &&
      _setTouchKeyboardVisibleBindingsReady();

  static bool _setTouchKeyboardVisibleBindingsReady() {
    return _isTabTipProcessAlive != null && _ensureTabTipHealthy != null;
  }

  /// Returns false when the native DLL or exports could not be loaded.
  static bool init() {
    if (!Platform.isWindows) return false;
    if (_isClassVisible != null) return true;
    try {
      if (!NativeDll.load()) {
        debugPrint('[DiagnosticBridge] Failed to load DLL: ${NativeDll.lastError}');
        return false;
      }
      _dylib = NativeDll.library;
      
      _isClassVisible = _dylib!
          .lookupFunction<IsClassVisibleNative, IsClassVisibleDart>(
              'IsClassVisible');

      _isTitleVisible = _dylib!
          .lookupFunction<IsTitleVisibleNative, IsTitleVisibleDart>(
              'IsTitleVisible');

      _isOskVisibleViaInputPane = _dylib!
          .lookupFunction<IsOskVisibleViaInputPaneNative, IsOskVisibleViaInputPaneDart>(
              'IsOskVisibleViaInputPane');

      _closeWindowByClass = _dylib!
          .lookupFunction<CloseWindowByClassNative, CloseWindowByClassDart>(
              'CloseWindowByClass');

      _closeWindowByTitle = _dylib!
          .lookupFunction<CloseWindowByTitleNative, CloseWindowByTitleDart>(
              'CloseWindowByTitle');

      _launchTabTipProcess = _dylib!
          .lookupFunction<LaunchTabTipProcessNative, LaunchTabTipProcessDart>(
              'LaunchTabTipProcess');

      // P0: health check bindings
      _isTabTipProcessAlive = _dylib!
          .lookupFunction<IsTabTipProcessAliveNative, IsTabTipProcessAliveDart>(
              'IsTabTipProcessAliveExport');
      _isTabletServiceRunning = _dylib!
          .lookupFunction<IsTabletServiceRunningNative, IsTabletServiceRunningDart>(
              'IsTabletServiceRunningExport');
      _ensureTabTipHealthy = _dylib!
          .lookupFunction<EnsureTabTipHealthyNative, EnsureTabTipHealthyDart>(
              'EnsureTabTipHealthyExport');

      // P2: dual-method visibility bindings
      _isVisibleMethodA = _dylib!
          .lookupFunction<IsTouchKeyboardVisibleMethodANative, IsTouchKeyboardVisibleMethodADart>(
              'IsTouchKeyboardVisibleMethodA');
      _isVisibleMethodB = _dylib!
          .lookupFunction<IsTouchKeyboardVisibleMethodBNative, IsTouchKeyboardVisibleMethodBDart>(
              'IsTouchKeyboardVisibleMethodB');
      _isVisibleMethodC = _dylib!
          .lookupFunction<IsTouchKeyboardVisibleMethodCNative, IsTouchKeyboardVisibleMethodCDart>(
              'IsTouchKeyboardVisibleMethodC');
      _isSlateMode = _dylib!
          .lookupFunction<IsSlateModeNative, IsSlateModeDart>(
              'IsSlateMode');
      _isSystemDocked = _dylib!
          .lookupFunction<IsSystemDockedNative, IsSystemDockedDart>(
              'IsSystemDocked');

      // Window enumeration for OSK window discovery
      _enumAllVisibleWindows = _dylib!
          .lookupFunction<EnumAllVisibleWindowsNative, EnumAllVisibleWindowsDart>(
              'EnumAllVisibleWindows');
      _freeEnumResult = _dylib!
          .lookupFunction<FreeEnumResultNative, FreeEnumResultDart>(
              'FreeEnumResult');

      debugPrint('[DiagnosticBridge] Successfully bound native diagnostic DLL functions.');

      // P0: Run startup health check immediately after binding
      _runStartupHealthCheck();
      return true;
    } catch (e) {
      debugPrint('[DiagnosticBridge] Failed to load native diagnostic functions: $e');
      return false;
    }
  }

  static void _runStartupHealthCheck() {
    if (_isTabTipProcessAlive == null) return;
    final processAlive = _isTabTipProcessAlive!();
    final serviceRunning = _isTabletServiceRunning != null ? _isTabletServiceRunning!() : false;
    debugPrint(
      '🩺 [P0 HEALTH CHECK] TabTip/TextInputHost alive: $processAlive | TabletInputService running: $serviceRunning'
    );
    if (!processAlive) {
      debugPrint('⚠️ [P0 HEALTH CHECK] TabTip process NOT alive at startup! Attempting recovery...');
      final result = _ensureTabTipHealthy!();
      if (result == 0) {
        debugPrint('✅ [P0 RECOVERY] TabTip was already alive (race condition - ok).');
      } else if (result == 1) {
        debugPrint('✅ [P0 RECOVERY] TabTip.exe relaunched successfully.');
      } else {
        debugPrint('❌ [P0 RECOVERY] TabTip.exe relaunch FAILED. OSK may not work.');
      }
    } else {
      debugPrint('✅ [P0 HEALTH CHECK] TabTip subsystem healthy at startup.');
    }
  }

  static bool isClassVisible(String className) {
    if (_isClassVisible == null) return false;
    final ptr = className.toNativeUtf8();
    try {
      return _isClassVisible!(ptr);
    } finally {
      malloc.free(ptr);
    }
  }

  static bool isTitleVisible(String windowTitle) {
    if (_isTitleVisible == null) return false;
    final ptr = windowTitle.toNativeUtf8();
    try {
      return _isTitleVisible!(ptr);
    } finally {
      malloc.free(ptr);
    }
  }

  static bool isOskVisibleViaInputPane() {
    if (_isOskVisibleViaInputPane == null) return false;
    try {
      return _isOskVisibleViaInputPane!();
    } catch (_) {
      return false;
    }
  }

  // P0: health check Dart API
  static bool isTabTipProcessAlive() {
    if (_isTabTipProcessAlive == null) return true; // assume OK if not bound
    return _isTabTipProcessAlive!();
  }

  static bool isTabletServiceRunning() {
    if (_isTabletServiceRunning == null) return true;
    return _isTabletServiceRunning!();
  }

  static int ensureTabTipHealthy() {
    if (_ensureTabTipHealthy == null) return 0;
    return _ensureTabTipHealthy!();
  }

  // P2: dual-method visibility Dart API
  static bool isVisibleMethodA() {
    if (_isVisibleMethodA == null) return false;
    return _isVisibleMethodA!();
  }

  static bool isVisibleMethodB() {
    if (_isVisibleMethodB == null) return false;
    return _isVisibleMethodB!();
  }

  static bool isVisibleMethodC() {
    if (_isVisibleMethodC == null) return false;
    return _isVisibleMethodC!();
  }

  static bool isSlateMode() {
    if (_isSlateMode == null) return false;
    return _isSlateMode!();
  }

  static bool isSystemDocked() {
    if (_isSystemDocked == null) return false;
    return _isSystemDocked!();
  }

  // Window enumeration - snapshot all visible top-level windows
  static List<String> enumAllVisibleWindows() {
    if (_enumAllVisibleWindows == null || _freeEnumResult == null) return [];
    final ptr = _enumAllVisibleWindows!();
    try {
      final raw = ptr.toDartString();
      return raw.split('\n').where((s) => s.isNotEmpty).toList();
    } finally {
      _freeEnumResult!(ptr);
    }
  }

  static void closeWindowByClass(String className) {
    if (_closeWindowByClass == null) return;
    final ptr = className.toNativeUtf8();
    try {
      _closeWindowByClass!(ptr);
    } finally {
      malloc.free(ptr);
    }
  }

  static void closeWindowByTitle(String windowTitle) {
    if (_closeWindowByTitle == null) return;
    final ptr = windowTitle.toNativeUtf8();
    try {
      _closeWindowByTitle!(ptr);
    } finally {
      malloc.free(ptr);
    }
  }

  static void launchTabTipProcess() {
    if (_launchTabTipProcess == null) return;
    try {
      _launchTabTipProcess!();
    } catch (_) {}
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final touchReady = TouchBridge.init(enableTouchToMouse: false);
  final diagnosticReady = DiagnosticBridge.init();
  runApp(OskTestBenchApp(
    touchBridgeReady: touchReady,
    diagnosticBridgeReady: diagnosticReady,
  ));
}

class OskTestBenchApp extends StatelessWidget {
  const OskTestBenchApp({
    super.key,
    required this.touchBridgeReady,
    required this.diagnosticBridgeReady,
  });

  final bool touchBridgeReady;
  final bool diagnosticBridgeReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OSK Mock B (Guard Test Bench)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      navigatorObservers: [
        KeyboardSuppressingNavigatorObserver(),
      ],
      builder: (context, child) {
        return GlobalTouchKeyboardGuard(
          key: GlobalTouchKeyboardGuard.globalKey,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: TestDashboardPage(
        touchBridgeReady: touchBridgeReady,
        diagnosticBridgeReady: diagnosticBridgeReady,
      ),
    );
  }
}

class TestDashboardPage extends StatefulWidget {
  const TestDashboardPage({
    super.key,
    required this.touchBridgeReady,
    required this.diagnosticBridgeReady,
  });

  final bool touchBridgeReady;
  final bool diagnosticBridgeReady;

  @override
  State<TestDashboardPage> createState() => _TestDashboardPageState();
}

class _TestDashboardPageState extends State<TestDashboardPage> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();
  String _dropdownValue = 'Option 1';
  double _zoomScale = 1.0;
  Timer? _visibilityTimer;
  Map<String, bool> _lastVisibilityStates = {};
  bool _lastOskOpenedByUs = false;
  bool _autoSnapshotDone = false;
  bool? _lastSlateMode;
  bool? _lastSystemDocked;
  bool _methodCVisible = false;
  bool _combinedOskVisible = false;

  bool get _bridgesReady => widget.touchBridgeReady && widget.diagnosticBridgeReady;

  @override
  void initState() {
    super.initState();
    _textFieldFocusNode.addListener(_handleTextFieldFocusChange);
    _logBridgeStatus();
    _startVisibilityMonitor();
  }

  void _logBridgeStatus() {
    if (_bridgesReady) {
      _log('✅ Native bridges connected (${NativeDll.resolvedPath ?? "windows_osk_guard_plugin.dll"})');
      _log('App Started: OSK Guard active via MaterialApp.builder (all routes protected)');
    } else {
      if (!widget.touchBridgeReady) {
        _log('❌ TouchBridge FAILED: ${TouchBridge.lastInitError ?? "unknown error"}');
      }
      if (!widget.diagnosticBridgeReady) {
        _log('❌ DiagnosticBridge FAILED: ${NativeDll.lastError ?? "unknown error"}');
      }
      _log('⚠️ Diagnostic buttons will not work until native DLL loads.');
    }
  }

  bool _requireBridge(String action) {
    if (_bridgesReady) return true;
    _log('❌ [$action] blocked — native DLL not connected.');
    return false;
  }

  void _startVisibilityMonitor() {
    if (!Platform.isWindows) return;

    _refreshVisibilitySnapshot(logInitial: true);

    _visibilityTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      _refreshVisibilitySnapshot();
    });
  }

  void _refreshVisibilitySnapshot({bool logInitial = false}) {
    if (!_bridgesReady) return;

    final currentStates = {
      'IPTIP_Main_Window (Class)': DiagnosticBridge.isClassVisible('IPTIP_Main_Window'),
      'Microsoft Text Input Application (Title)': DiagnosticBridge.isTitleVisible('Microsoft Text Input Application'),
      'Windows Input Experience (Title)': DiagnosticBridge.isTitleVisible('Windows Input Experience'),
      'OSKMainClass (Class)': DiagnosticBridge.isClassVisible('OSKMainClass'),
    };
    final methodC = DiagnosticBridge.isVisibleMethodC();
    final combinedVisible = TouchBridge.isTouchKeyboardVisible();

    if (logInitial) {
      _lastVisibilityStates = currentStates;
      _methodCVisible = methodC;
      _combinedOskVisible = combinedVisible;
      _lastSlateMode = DiagnosticBridge.isSlateMode();
      _lastSystemDocked = DiagnosticBridge.isSystemDocked();
      _log('🔍 [OSK MONITOR] Monitoring started. Initial states: $_lastVisibilityStates');
      _log('💻 [DEVICE POSTURE] Slate/Tablet Mode: $_lastSlateMode | System Docked: $_lastSystemDocked');
      setState(() {});
      return;
    }

    bool stateChanged = false;
    final changes = <String>[];

    currentStates.forEach((key, value) {
      if (_lastVisibilityStates[key] != value) {
        stateChanged = true;
        changes.add('$key: ${_lastVisibilityStates[key]} -> $value');
      }
    });

    if (stateChanged) {
      _log('🔔 [OSK STATE CHANGE] Detected changes: ${changes.join(", ")}');
      final methodA = DiagnosticBridge.isVisibleMethodA();
      final methodB = DiagnosticBridge.isVisibleMethodB();
      final methodCNow = DiagnosticBridge.isVisibleMethodC();
      _log('📊 [P2 DETECT] MethodA(FindWindow): $methodA | MethodB(AppFrameWin): $methodB | MethodC(InputPane): $methodCNow');
    }

    final currentSlate = DiagnosticBridge.isSlateMode();
    final currentDocked = DiagnosticBridge.isSystemDocked();
    if (_lastSlateMode != currentSlate || _lastSystemDocked != currentDocked) {
      _log('🔄 [DEVICE MODE CHANGE] Slate/Tablet Mode: $_lastSlateMode -> $currentSlate | System Docked: $_lastSystemDocked -> $currentDocked');
    }

    final oskOpenedByUs = TouchBridge.getOskOpenedByUs();
    if (oskOpenedByUs && !_lastOskOpenedByUs && !_autoSnapshotDone) {
      _autoSnapshotDone = true;
      _log('📸 [AUTO SNAPSHOT] OSK opened by guard — snapshotting windows in 600ms...');
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _snapshotWindows();
      });
    }
    if (!oskOpenedByUs) {
      _lastOskOpenedByUs = false;
      _autoSnapshotDone = false;
    }
    _lastOskOpenedByUs = oskOpenedByUs;

    final uiChanged = stateChanged ||
        _methodCVisible != methodC ||
        _combinedOskVisible != combinedVisible ||
        _lastSlateMode != currentSlate ||
        _lastSystemDocked != currentDocked;

    if (uiChanged && mounted) {
      setState(() {
        _lastVisibilityStates = currentStates;
        _methodCVisible = methodC;
        _combinedOskVisible = combinedVisible;
        _lastSlateMode = currentSlate;
        _lastSystemDocked = currentDocked;
      });
    }
  }

  void _handleTextFieldFocusChange() {
    _log('FOCUS CHANGE: TextField hasFocus = ${_textFieldFocusNode.hasFocus}');
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    _textFieldFocusNode.removeListener(_handleTextFieldFocusChange);
    _textFieldFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final logLine = '[$timestamp] $message';
    print(logLine); // Output to standard output (captured in terminal)
    setState(() {
      _logs.add(logLine);
      if (_logs.length > 200) {
        _logs.removeAt(0);
      }
    });
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Widget _buildStatusRow(String label, bool isVisible) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isVisible ? Colors.greenAccent : Colors.redAccent,
              boxShadow: isVisible
                  ? [
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isVisible ? 'VISIBLE' : 'HIDDEN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isVisible ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  void _logStatus() {
    if (!_requireBridge('Log Status Now')) return;
    final status = {
      'IPTIP_Main_Window (Class)': DiagnosticBridge.isClassVisible('IPTIP_Main_Window'),
      'Microsoft Text Input Application (Title)': DiagnosticBridge.isTitleVisible('Microsoft Text Input Application'),
      'Windows Input Experience (Title)': DiagnosticBridge.isTitleVisible('Windows Input Experience'),
      'OSKMainClass (Class)': DiagnosticBridge.isClassVisible('OSKMainClass'),
    };
    _log('📊 [OSK STATUS QUERY] FindWindow states: $status');
    // P2: triple-method comparison
    final methodA = DiagnosticBridge.isVisibleMethodA();
    final methodB = DiagnosticBridge.isVisibleMethodB();
    final methodC = DiagnosticBridge.isVisibleMethodC();
    _log('📊 [P2 DETECT] MethodA(FindWindow/legacy): $methodA | MethodB(AppFrameWindow/Win11): $methodB | MethodC(InputPane): $methodC');
    // Device posture status
    final isSlate = DiagnosticBridge.isSlateMode();
    final isDocked = DiagnosticBridge.isSystemDocked();
    _log('💻 [DEVICE POSTURE] Slate/Tablet Mode: $isSlate | System Docked: $isDocked');
    // P0: health status
    final processAlive = DiagnosticBridge.isTabTipProcessAlive();
    final serviceRunning = DiagnosticBridge.isTabletServiceRunning();
    _log('🩺 [P0 HEALTH] TabTip process alive: $processAlive | TabletInputService running: $serviceRunning');
  }

  void _runHealthCheck() {
    if (!_requireBridge('P0 Health Check')) return;
    _log('🩺 [P0 HEALTH CHECK] Running manual health check...');
    final processAlive = DiagnosticBridge.isTabTipProcessAlive();
    final serviceRunning = DiagnosticBridge.isTabletServiceRunning();
    _log('🩺 [P0 HEALTH] TabTip process alive: $processAlive | TabletInputService running: $serviceRunning');
    if (!processAlive) {
      _log('⚠️ [P0 HEALTH] TabTip NOT alive! Attempting recovery...');
      final result = DiagnosticBridge.ensureTabTipHealthy();
      if (result == 0) {
        _log('✅ [P0 RECOVERY] Was already alive (recheck ok).');
      } else if (result == 1) {
        _log('✅ [P0 RECOVERY] TabTip.exe relaunched. Wait 1-2s then try OSK.');
      } else {
        _log('❌ [P0 RECOVERY] Relaunch failed. System OSK subsystem may be broken.');
      }
    } else {
      _log('✅ [P0 HEALTH] TabTip subsystem is healthy.');
    }
  }

  void _snapshotWindows() {
    if (!_requireBridge('Snapshot Windows')) return;
    _log('🪟 [WIN SNAPSHOT] Enumerating ALL visible top-level windows...');
    final windows = DiagnosticBridge.enumAllVisibleWindows();
    if (windows.isEmpty) {
      _log('🪟 [WIN SNAPSHOT] No visible windows found (or not bound).');
      return;
    }
    _log('🪟 [WIN SNAPSHOT] Found ${windows.length} visible windows:');
    for (final w in windows) {
      final parts = w.split('|');
      final cls = parts.isNotEmpty ? parts[0] : '?';
      final title = parts.length > 1 ? parts[1] : '?';
      final dims = parts.length > 2 ? parts[2] : '?';
      // Highlight likely OSK/keyboard windows
      final isOsk = cls.toLowerCase().contains('tip') ||
          cls.toLowerCase().contains('input') ||
          title.toLowerCase().contains('keyboard') ||
          title.toLowerCase().contains('input') ||
          title.toLowerCase().contains('text') ||
          cls == 'ApplicationFrameWindow' ||
          cls == 'Windows.UI.Core.CoreWindow';
      final marker = isOsk ? ' ⭐ OSK?' : '';
      _log('  CLASS="$cls" TITLE="$title" SIZE=$dims$marker');
    }
  }

  // P0 fix: _forceCloseAll now uses ONLY safe COM Toggle (no SC_CLOSE)
  void _forceCloseAll() {
    if (!_requireBridge('Force Close All')) return;
    _log('🧹 [OSK SAFE CLOSE] Using COM Toggle (graceful dismiss only)...');
    TouchBridge.setKeyboardVisible(false);
    _log('✅ [OSK SAFE CLOSE] Done. SC_CLOSE removed to preserve TabTip service health.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OSK Mock B (Guard Test Bench)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    _bridgesReady ? Icons.link : Icons.link_off,
                    size: 16,
                    color: _bridgesReady ? Colors.greenAccent : Colors.redAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _bridgesReady ? 'DLL connected' : 'DLL missing',
                    style: TextStyle(
                      fontSize: 12,
                      color: _bridgesReady ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Listener(
          onPointerDown: (event) {
            _log('RAW POINTER DOWN: id=${event.pointer}, kind=${event.kind.name}, pos=${event.position}');
          },
        onPointerUp: (event) {
          _log('RAW POINTER UP: id=${event.pointer}, kind=${event.kind.name}, pos=${event.position}');
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left panel: Controls
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('1. Test Controls', style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 10),
                                    OskTextField(
                                      child: TextField(
                                        focusNode: _textFieldFocusNode,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          labelText: 'Enter text here',
                                          hintText: 'Tap to trigger OSK',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      value: _dropdownValue,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        labelText: 'Select Option',
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'Option 1', child: Text('Option 1')),
                                        DropdownMenuItem(value: 'Option 2', child: Text('Option 2')),
                                        DropdownMenuItem(value: 'Option 3', child: Text('Option 3')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _dropdownValue = val;
                                          });
                                          _log('DROPDOWN CHANGE: Selected $val');
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 15),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        OskActionButton(
                                          onPressed: () {
                                            _log('BUTTON PRESS: Action Button clicked');
                                          },
                                          child: const Text('Action Button'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            _textFieldFocusNode.unfocus();
                                            _log('BUTTON PRESS: Force Unfocus clicked');
                                          },
                                          child: const Text('Force Unfocus'),
                                        ),
                                        OskActionButton(
                                          onPressed: () {
                                            _log('BUTTON PRESS: Navigate to Page 2');
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => const SecondPage()),
                                            );
                                          },
                                          child: const Text('Navigate to Page 2'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Card(
                              color: const Color(0xFF0F172A),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('2. OSK Diagnostic Panel', style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 10),
                                    _buildStatusRow('IPTIP_Main_Window (Class)', _lastVisibilityStates['IPTIP_Main_Window (Class)'] ?? false),
                                    _buildStatusRow('Microsoft Text Input (Title)', _lastVisibilityStates['Microsoft Text Input Application (Title)'] ?? false),
                                    _buildStatusRow('Windows Input Exp (Title)', _lastVisibilityStates['Windows Input Experience (Title)'] ?? false),
                                    _buildStatusRow('OSKMainClass (Class)', _lastVisibilityStates['OSKMainClass (Class)'] ?? false),
                                    _buildStatusRow('Method C (InputPane COM)', _methodCVisible),
                                    _buildStatusRow('Combined (TouchBridge)', _combinedOskVisible),
                                    const Divider(height: 20),
                                    Text('3. Device Posture Panel', style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 10),
                                    _buildStatusRow('Slate/Tablet Mode (0x2003)', _lastSlateMode ?? false),
                                    _buildStatusRow('Laptop/Desktop Mode', !(_lastSlateMode ?? false)),
                                    _buildStatusRow('System Docked (0x2004)', _lastSystemDocked ?? false),
                                    const Divider(height: 20),
                                    Text('Actions:', style: Theme.of(context).textTheme.titleSmall),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.keyboard, size: 16),
                                          label: const Text('COM Toggle', style: TextStyle(fontSize: 11)),
                                          onPressed: () {
                                            if (!_requireBridge('COM Toggle')) return;
                                            _log('[DIAGNOSTIC] Calling SetTouchKeyboardVisible(true)...');
                                            TouchBridge.setOskOpenedByUs(true);
                                            TouchBridge.setKeyboardVisible(true);
                                            _refreshVisibilitySnapshot();
                                          },
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.keyboard_hide, size: 16),
                                          label: const Text('COM Hide', style: TextStyle(fontSize: 11)),
                                          onPressed: () {
                                            if (!_requireBridge('COM Hide')) return;
                                            _log('[DIAGNOSTIC] Calling SetTouchKeyboardVisible(false)...');
                                            TouchBridge.setKeyboardVisible(false);
                                            _refreshVisibilitySnapshot();
                                          },
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.rocket_launch, size: 16),
                                          label: const Text('Launch TabTip', style: TextStyle(fontSize: 11)),
                                          onPressed: () {
                                            if (!_requireBridge('Launch TabTip')) return;
                                            _log('[DIAGNOSTIC] Launching TabTip.exe process...');
                                            DiagnosticBridge.launchTabTipProcess();
                                          },
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.close, size: 16),
                                          label: const Text('Close IPTIP', style: TextStyle(fontSize: 11)),
                                          onPressed: () {
                                            if (!_requireBridge('Close IPTIP')) return;
                                            _log('[DIAGNOSTIC] Closing IPTIP_Main_Window (SC_CLOSE — risky)...');
                                            DiagnosticBridge.closeWindowByClass('IPTIP_Main_Window');
                                          },
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.close, size: 16),
                                          label: const Text('Close MS Input', style: TextStyle(fontSize: 11)),
                                          onPressed: () {
                                            if (!_requireBridge('Close MS Input')) return;
                                            _log('[DIAGNOSTIC] Closing Microsoft Text Input Application (SC_CLOSE — risky)...');
                                            DiagnosticBridge.closeWindowByTitle('Microsoft Text Input Application');
                                          },
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.close, size: 16),
                                          label: const Text('Close Win Input', style: TextStyle(fontSize: 11)),
                                          onPressed: () {
                                            if (!_requireBridge('Close Win Input')) return;
                                            _log('[DIAGNOSTIC] Closing Windows Input Experience (SC_CLOSE — risky)...');
                                            DiagnosticBridge.closeWindowByTitle('Windows Input Experience');
                                          },
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.close, size: 16),
                                          label: const Text('Close OSK Class', style: TextStyle(fontSize: 11)),
                                          onPressed: () {
                                            if (!_requireBridge('Close OSK Class')) return;
                                            _log('[DIAGNOSTIC] Closing OSKMainClass (SC_CLOSE — risky)...');
                                            DiagnosticBridge.closeWindowByClass('OSKMainClass');
                                          },
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.cleaning_services, size: 16),
                                          label: const Text('Force Close All', style: TextStyle(fontSize: 11)),
                                          onPressed: _forceCloseAll,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade900,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.refresh, size: 16),
                                          label: const Text('Log Status Now', style: TextStyle(fontSize: 11)),
                                          onPressed: _logStatus,
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.health_and_safety, size: 16),
                                          label: const Text('P0 Health Check', style: TextStyle(fontSize: 11)),
                                          onPressed: _runHealthCheck,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal.shade800,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.window, size: 16),
                                          label: const Text('🪟 Snapshot Windows', style: TextStyle(fontSize: 11)),
                                          onPressed: _snapshotWindows,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange.shade900,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Right panel: Zoom Area
                    Expanded(
                      flex: 1,
                      child: Card(
                        color: Colors.blueGrey.shade900,
                        child: ClipRect(
                          child: GestureDetector(
                            onScaleStart: (details) {
                              _log('SCALE START: pointers=${details.pointerCount}, focalPoint=${details.focalPoint}');
                            },
                            onScaleUpdate: (details) {
                              setState(() {
                                _zoomScale = details.scale;
                              });
                              _log('SCALE UPDATE: scale=${details.scale.toStringAsFixed(2)}, rotation=${details.rotation.toStringAsFixed(2)}');
                            },
                            onScaleEnd: (details) {
                              _log('SCALE END');
                            },
                            child: Container(
                              alignment: Alignment.center,
                              color: Colors.transparent,
                              child: Transform.scale(
                                scale: _zoomScale,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.zoom_out_map, size: 48, color: Colors.blue),
                                    const SizedBox(height: 10),
                                    Text('Multi-touch Zoom Area', style: Theme.of(context).textTheme.titleSmall),
                                    Text('Pinch or pan here', style: TextStyle(color: Colors.grey.shade400)),
                                    const SizedBox(height: 5),
                                    Text('Current Scale: ${_zoomScale.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Bottom panel: Logs console
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('2. Live Logs (Captured)', style: Theme.of(context).textTheme.titleMedium),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _logs.clear();
                                });
                              },
                              child: const Text('Clear'),
                            )
                          ],
                        ),
                        const Divider(),
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              return Text(
                                _logs[index],
                                style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Second Page (Navigation Test)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.deepPurple),
            const SizedBox(height: 20),
            Text(
              'This is the Second Page!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'TextField on Page 2',
                  hintText: 'Tap to edit on Page 2',
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
