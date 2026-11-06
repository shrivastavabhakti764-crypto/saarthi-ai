class AppConfig {
  // With `adb reverse tcp:8000 tcp:8000`, the phone's 127.0.0.1:8000 reaches the laptop.
  static const apiBaseUrl = 'http://127.0.0.1:8000';
}