# windows_osk_guard

A Flutter plugin for Windows to suppress the default touch/on-screen keyboard (OSK) on non-text taps and manage it programmatically for touch and stylus inputs, without interfering with physical mouse clicks.

## Features
* **Mouse vs. Touch Detection:** Distinguishes physical mouse clicks from touch taps.
* **Registry/Process Suppress:** Suppresses Windows default touch keyboard auto-invoke behaviors.
* **Auto-unfocus:** Automatically clears focus and closes the keyboard when tapping outside editable fields (like TextFields).
* **Navigator Integration:** Clears active IME context automatically during navigation page transitions to prevent the keyboard from popping up on next route load.

## Installation

Add this package to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  windows_osk_guard:
    git:
      url: https://github.com/karsun666/windows_osk_guard.git
      ref: main
```

## Usage

### 1. Global Touch Keyboard Guard
Wrap your root `MaterialApp` builder with the `GlobalTouchKeyboardGuard` widget:

```dart
import 'package:windows_osk_guard/windows_osk_guard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        return GlobalTouchKeyboardGuard(
          key: GlobalTouchKeyboardGuard.globalKey,
          child: child ?? const SizedBox(),
        );
      },
      home: const HomeScreen(),
    );
  }
}
```

### 2. Keyboard Suppressing Navigator Observer
To prevent stale OSK inputs when navigating between routes, add the `KeyboardSuppressingNavigatorObserver` to your `navigatorObservers`:

```dart
MaterialApp(
  navigatorObservers: [
    KeyboardSuppressingNavigatorObserver(),
  ],
  // ...
)
```
