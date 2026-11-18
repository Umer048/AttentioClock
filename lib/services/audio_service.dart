import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService instance = AudioService._();
  AudioService._();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  Future<void> play(String soundId) async {
    if (_isPlaying) return;
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/$soundId.wav'));
    _isPlaying = true;
  }

  Future<void> stop() async {
    if (!_isPlaying) return;
    await _player.stop();
    _isPlaying = false;
  }
}