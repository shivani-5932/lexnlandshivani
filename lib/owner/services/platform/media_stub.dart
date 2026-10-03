// Mobile (non-web) audio implementation.
//   • Recording  → `record` package (AAC/m4a, universally supported on Android)
//   • Playback   → `audioplayers`
// (Web uses media_web.dart via the conditional export in media.dart.)
import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'media_iface.dart';

VoiceRecorderHandle createVoiceRecorder() => _MobileVoiceRecorder();
AudioPlayerHandle createAudioPlayer() => _MobileAudioPlayer();

class _MobileVoiceRecorder implements VoiceRecorderHandle {
  final AudioRecorder _rec = AudioRecorder();
  String? _path;

  @override
  bool get isSupported => true;

  @override
  Future<bool> start() async {
    try {
      if (!await _rec.hasPermission()) return false;
      final dir = await getTemporaryDirectory();
      _path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      // AAC-LC in an .m4a container is supported on essentially every Android
      // and iOS device (unlike opus, which crashes on many of them).
      await _rec.start(
          const RecordConfig(encoder: AudioEncoder.aacLc), path: _path!);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<int>?> stop() async {
    try {
      final p = await _rec.stop();
      final path = p ?? _path;
      if (path == null) return null;
      final f = File(path);
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }
}

class _MobileAudioPlayer implements AudioPlayerHandle {
  final AudioPlayer _p = AudioPlayer();
  double _dur = 0;
  double _cur = 0;
  void Function(double duration)? _onLoaded;
  void Function()? _onEnded;

  _MobileAudioPlayer() {
    _p.onDurationChanged.listen((d) {
      _dur = d.inMilliseconds / 1000.0;
      _onLoaded?.call(_dur);
    });
    _p.onPositionChanged.listen((pos) {
      _cur = pos.inMilliseconds / 1000.0;
    });
    _p.onPlayerComplete.listen((_) {
      _cur = 0;
      _onEnded?.call();
    });
  }

  @override
  bool get isSupported => true;

  @override
  void load(String url) {
    _p.setSourceUrl(url);
  }

  @override
  void play() {
    _p.resume();
  }

  @override
  void pause() {
    _p.pause();
  }

  @override
  void seek(double seconds) {
    _p.seek(Duration(milliseconds: (seconds * 1000).round()));
  }

  @override
  double get currentTime => _cur;

  @override
  double get duration => _dur;

  @override
  set onLoaded(void Function(double duration)? cb) {
    _onLoaded = cb;
  }

  @override
  set onEnded(void Function()? cb) {
    _onEnded = cb;
  }

  @override
  void dispose() {
    _p.dispose();
  }
}
