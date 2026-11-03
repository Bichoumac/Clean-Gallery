import 'package:clean_gallery/domain/slideshow.dart';

/// Plays the music of a slideshow and picks tracks from the phone.
///
/// One track at a time, in a loop. The Android implementation uses the
/// platform media player; tests use a fake.
abstract interface class MusicPlayer {
  /// Starts [music] in a loop at [volume] (0 to 1), replacing any track
  /// playing. Returns `false` when it cannot be played (a file deleted or
  /// no longer readable); nothing plays then. Does nothing for no music.
  Future<bool> play(SlideshowMusic music, {double volume = 1});

  /// Pauses the track.
  Future<void> pause();

  /// Continues the paused track.
  Future<void> resume();

  /// Sets the volume, 0 to 1, e.g. to fade out.
  Future<void> setVolume(double volume);

  /// Stops the track.
  Future<void> stop();

  /// Lets the user pick an audio file with the system file picker, without
  /// any audio permission; `null` when cancelled. The app keeps read
  /// access to that file until [release].
  Future<DeviceMusic?> pick();

  /// Gives back the read access to the track [uri], no longer used.
  Future<void> release(String uri);
}
