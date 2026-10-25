import 'package:clean_gallery/platform/platform_bridge.dart';
import 'package:flutter/services.dart';

/// Android implementation of [PlatformBridge] over the `clean_gallery/platform`
/// MethodChannel, handled by `MainActivity.kt`.
///
/// Method contract is documented in `docs/platform-android.md`.
final class AndroidPlatformBridge implements PlatformBridge {
  /// Creates the bridge. [channel] can be replaced in tests.
  AndroidPlatformBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'clean_gallery/platform';

  final MethodChannel _channel;

  @override
  Future<bool> isMediaManagementGranted() async {
    final granted = await _channel.invokeMethod<bool>(
      'isMediaManagementGranted',
    );
    return granted ?? false;
  }

  @override
  Future<void> openMediaManagementSettings() {
    return _channel.invokeMethod<void>('openMediaManagementSettings');
  }

  /// File sizes in bytes of the MediaStore items with the given [ids].
  ///
  /// Android-only helper used by `AndroidMediaSource`: `photo_manager` does
  /// not expose file sizes. Items that no longer exist are left out.
  Future<Map<String, int>> mediaSizes(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final sizes = await _channel.invokeMapMethod<String, int>('mediaSizes', {
      'ids': ids,
    });
    return sizes ?? const {};
  }

  @override
  Future<int> sdkVersion() async {
    final version = await _channel.invokeMethod<int>('sdkVersion');
    return version ?? 0;
  }
}
