import 'package:clean_gallery/domain/slideshow.dart';
import 'package:clean_gallery/platform/music_player.dart';
import 'package:flutter/services.dart';

/// Android [MusicPlayer] over the `clean_gallery/platform` channel, handled
/// by `SlideshowMusic.kt` (a `MediaPlayer` and the `ACTION_OPEN_DOCUMENT`
/// picker). See `docs/platform-android.md`.
final class AndroidMusicPlayer implements MusicPlayer {
  /// Creates the player. [channel] can be replaced in tests.
  AndroidMusicPlayer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('clean_gallery/platform');

  final MethodChannel _channel;

  @override
  Future<bool> play(SlideshowMusic music, {double volume = 1}) async {
    final (uri, asset) = switch (music) {
      NoMusic() => (null, null),
      DeviceMusic(:final uri) => (uri, null),
      BundledMusic(:final trackId) => (
        null,
        bundledTracks.where((t) => t.id == trackId).firstOrNull?.asset,
      ),
    };
    if (uri == null && asset == null) return false;
    try {
      final played = await _channel.invokeMethod<bool>('musicPlay', {
        'uri': uri,
        'asset': asset,
        'volume': volume,
      });
      return played ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> pause() => _channel.invokeMethod<void>('musicPause');

  @override
  Future<void> resume() => _channel.invokeMethod<void>('musicResume');

  @override
  Future<void> setVolume(double volume) =>
      _channel.invokeMethod<void>('musicVolume', {'volume': volume});

  @override
  Future<void> stop() => _channel.invokeMethod<void>('musicStop');

  @override
  Future<DeviceMusic?> pick() async {
    final picked = await _channel.invokeMapMethod<String, Object?>('pickMusic');
    final uri = picked?['uri'];
    if (uri is! String) return null;
    final name = picked?['name'];
    return DeviceMusic(uri: uri, name: name is String ? name : '');
  }

  @override
  Future<void> release(String uri) =>
      _channel.invokeMethod<void>('releaseMusic', {'uri': uri});
}
