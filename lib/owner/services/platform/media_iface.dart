/// Cross-platform audio interfaces. Real implementations exist on web;
/// mobile uses no-op stubs (voice messages are web-only for now).

abstract class VoiceRecorderHandle {
  bool get isSupported;

  /// Starts recording. Returns true if recording actually started.
  Future<bool> start();

  /// Stops recording and returns the encoded audio bytes (webm), or null.
  Future<List<int>?> stop();
}

abstract class AudioPlayerHandle {
  bool get isSupported;
  void load(String url);
  void play();
  void pause();
  void seek(double seconds);
  double get currentTime;
  double get duration;
  set onLoaded(void Function(double duration)? cb);
  set onEnded(void Function()? cb);
  void dispose();
}
