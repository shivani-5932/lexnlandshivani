import 'dart:async';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'media_iface.dart';

VoiceRecorderHandle createVoiceRecorder() => _WebVoiceRecorder();
AudioPlayerHandle createAudioPlayer() => _WebAudioPlayer();

class _WebVoiceRecorder implements VoiceRecorderHandle {
  html.MediaRecorder? _recorder;
  final List<dynamic> _chunks = [];

  @override
  bool get isSupported => true;

  @override
  Future<bool> start() async {
    try {
      final stream =
          await html.window.navigator.mediaDevices?.getUserMedia({'audio': true});
      if (stream == null) return false;
      _chunks.clear();
      final mime = html.MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
          ? 'audio/webm;codecs=opus'
          : html.MediaRecorder.isTypeSupported('audio/webm')
              ? 'audio/webm'
              : '';
      _recorder = mime.isNotEmpty
          ? html.MediaRecorder(stream, {'mimeType': mime})
          : html.MediaRecorder(stream);
      _recorder!.addEventListener('dataavailable', (e) {
        final blob = (e as html.BlobEvent).data;
        if (blob != null && blob.size > 0) _chunks.add(blob);
      });
      _recorder!.start(250);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<int>?> stop() async {
    final rec = _recorder;
    if (rec == null) return null;
    rec.requestData();
    final completer = Completer<void>();
    rec.addEventListener('stop', (_) {
      if (!completer.isCompleted) completer.complete();
    });
    rec.stop();
    await completer.future;
    rec.stream?.getTracks().forEach((t) => t.stop());
    _recorder = null;
    if (_chunks.isEmpty) return null;
    final blob = html.Blob(List<dynamic>.from(_chunks), 'audio/webm');
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoad.first;
    final result = reader.result;
    _chunks.clear();
    if (result is ByteBuffer) return result.asUint8List();
    if (result is Uint8List) return result;
    try {
      return (result as dynamic).buffer.asUint8List() as List<int>;
    } catch (_) {
      return null;
    }
  }
}

class _WebAudioPlayer implements AudioPlayerHandle {
  html.AudioElement? _audio;
  void Function(double)? _onLoaded;
  void Function()? _onEnded;

  @override
  bool get isSupported => true;

  @override
  void load(String url) {
    _audio = html.AudioElement()
      ..src = url
      ..preload = 'metadata';
    html.document.body!.append(_audio!);
    _audio!.onLoadedMetadata.listen((_) {
      final d = (_audio!.duration as num).toDouble();
      _onLoaded?.call(d);
    });
    _audio!.onEnded.listen((_) => _onEnded?.call());
  }

  @override
  void play() => _audio?.play();

  @override
  void pause() => _audio?.pause();

  @override
  void seek(double seconds) {
    if (_audio != null) _audio!.currentTime = seconds;
  }

  @override
  double get currentTime => _audio?.currentTime.toDouble() ?? 0.0;

  @override
  double get duration {
    final d = _audio?.duration;
    if (d == null) return 0.0;
    final v = (d as num).toDouble();
    return v.isFinite ? v : 0.0;
  }

  @override
  set onLoaded(void Function(double)? cb) => _onLoaded = cb;

  @override
  set onEnded(void Function()? cb) => _onEnded = cb;

  @override
  void dispose() {
    _audio?.pause();
    _audio?.remove();
    _audio = null;
  }
}
