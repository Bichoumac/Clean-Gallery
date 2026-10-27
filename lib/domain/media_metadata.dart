/// Camera and location metadata of a photo or video, read from the file
/// for the viewer's info panel. Every value is optional: phones, cameras
/// and apps write different subsets, and videos only carry a location.
final class MediaMetadata {
  /// Creates metadata; leave out what the file does not have.
  const MediaMetadata({
    this.make,
    this.model,
    this.lens,
    this.iso,
    this.aperture,
    this.exposure,
    this.focalLength,
    this.focalLength35,
    this.latitude,
    this.longitude,
  });

  /// Nothing known.
  static const empty = MediaMetadata();

  /// Camera maker, e.g. `samsung`.
  final String? make;

  /// Camera model, e.g. `Galaxy A54 5G`.
  final String? model;

  /// Lens model.
  final String? lens;

  /// ISO sensitivity.
  final int? iso;

  /// Aperture as an f-number, e.g. `1.8`.
  final double? aperture;

  /// Shutter speed, in seconds.
  final double? exposure;

  /// Focal length, in millimetres.
  final double? focalLength;

  /// Focal length in 35 mm equivalent, in millimetres.
  final double? focalLength35;

  /// Latitude, in degrees.
  final double? latitude;

  /// Longitude, in degrees.
  final double? longitude;

  /// Whether a location is known.
  bool get hasLocation => latitude != null && longitude != null;

  /// The camera, maker and model, without the maker twice when the model
  /// already starts with it (`Canon` + `Canon EOS R6`).
  String? get camera {
    final make = this.make;
    final model = this.model;
    if (model == null) return make;
    if (make == null || model.toLowerCase().startsWith(make.toLowerCase())) {
      return model;
    }
    return '$make $model';
  }
}
