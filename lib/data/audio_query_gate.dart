import 'dart:async';

/// Global serial queue ensuring that ONLY ONE on_audio_query platform
/// channel call executes at any given time.
///
/// This completely resolves the Android plugin bug:
/// `java.lang.IllegalStateException: Reply already submitted`
/// caused by concurrent queries reusing a single Result callback.
class AudioQueryGate {
  AudioQueryGate._();

  static Future<void> _tail = Future.value();

  static Future<T> run<T>(Future<T> Function() task) {
    final c = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        c.complete(await task());
      } catch (e, st) {
        c.completeError(e, st);
      }
    });
    return c.future;
  }
}
