import 'dart:ffi';
import 'dart:io';

/// Resolves and opens the plugin DLL bundled next to the Windows executable.
class NativeDll {
  NativeDll._();

  static DynamicLibrary? _library;
  static String? _resolvedPath;
  static String? _lastError;

  static DynamicLibrary? get library => _library;
  static String? get resolvedPath => _resolvedPath;
  static String? get lastError => _lastError;
  static bool get isReady => _library != null;

  static bool load() {
    if (_library != null) return true;
    if (!Platform.isWindows) {
      _lastError = 'Not running on Windows';
      return false;
    }

    final candidates = <String>[
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}windows_osk_guard_plugin.dll',
      'windows_osk_guard_plugin.dll',
    ];

    for (final path in candidates) {
      try {
        _library = DynamicLibrary.open(path);
        _resolvedPath = path;
        _lastError = null;
        return true;
      } catch (e) {
        _lastError = '$path: $e';
      }
    }
    return false;
  }
}
