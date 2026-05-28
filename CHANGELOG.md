## 1.0.1

* Fix: Implement a 12-pixel touch slop threshold in subclass proc to improve tap and swipe tolerance.

## 1.0.0

* Initial release of the Windows OSK Suppressor & Touch Guard.
* Integrates native Windows subclassing procedure on child viewport.
* Leverages Win32 extra message info (`GetMessageExtraInfo`) to accurately filter touch events.
* Adds a global gesture listener (`GlobalTouchKeyboardGuard`) and navigation observer (`KeyboardSuppressingNavigatorObserver`).
