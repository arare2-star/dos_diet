import 'package:audioplayers/audioplayers.dart';

/// 効果音の再生。短いSEは使い捨てプレイヤー、リール回転音だけループ用を使い回す
class Sfx {
  Sfx._();

  static bool _initialized = false;
  static final AudioPlayer _loop = AudioPlayer();

  static Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    // マナーモード（サイレントスイッチ）に従い、他アプリの音楽も止めない
    await AudioPlayer.global.setAudioContext(
      AudioContextConfig(
        respectSilence: true,
        focus: AudioContextConfigFocus.mixWithOthers,
      ).build(),
    );
    await _loop.setReleaseMode(ReleaseMode.loop);
  }

  /// 単発の効果音（assets/sounds/`name`.wav）
  static Future<void> play(String name, {double volume = 1.0}) async {
    try {
      await _ensureInit();
      final player = AudioPlayer();
      player.onPlayerComplete.listen((_) => player.dispose());
      await player.play(AssetSource('sounds/$name.wav'), volume: volume);
    } catch (_) {
      // 音が鳴らなくてもアプリの動作は止めない
    }
  }

  /// ループ再生を開始（リール回転音など）
  static Future<void> startLoop(String name, {double volume = 1.0}) async {
    try {
      await _ensureInit();
      await _loop.play(AssetSource('sounds/$name.wav'), volume: volume);
    } catch (_) {}
  }

  static Future<void> stopLoop() async {
    try {
      await _loop.stop();
    } catch (_) {}
  }
}
