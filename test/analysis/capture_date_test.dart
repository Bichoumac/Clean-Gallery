import 'package:clean_gallery/analysis/capture_date.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 26, 12);

  DateTime? parse(String name, {DateTime? sameDayAs}) =>
      dateFromFileName(name, now: now, sameDayAs: sameDayAs);

  group('dateFromFileName', () {
    test('camera and screenshot names with a time', () {
      final expected = DateTime(2024, 3, 15, 14, 22, 33);
      for (final name in [
        'IMG_20240315_142233.jpg',
        'VID_20240315_142233.mp4',
        '20240315_142233.jpg',
        'PXL_20240315_142233123.jpg',
        'MVIMG_20240315_142233.jpg',
        'Screenshot_20240315-142233_Chrome.jpg',
        'Screenshot_2024-03-15-14-22-33-123_com.android.chrome.jpg',
        'Screen_Recording_20240315-142233_YouTube.mp4',
        'signal-2024-03-15-142233.jpg',
        'PHOTO-2024-03-15-14-22-33.jpg',
      ]) {
        expect(parse(name), expected, reason: name);
      }
    });

    test('messaging names with a date only: noon', () {
      expect(parse('IMG-20240315-WA0001.jpg'), DateTime(2024, 3, 15, 12));
      expect(parse('VID-20240315-WA0007.mp4'), DateTime(2024, 3, 15, 12));
    });

    test('a date only keeps the platform time on the same day', () {
      final added = DateTime(2024, 3, 15, 18, 5);
      expect(parse('IMG-20240315-WA0001.jpg', sameDayAs: added), added);
      expect(
        parse('IMG-20240315-WA0001.jpg', sameDayAs: DateTime(2024, 4)),
        DateTime(2024, 3, 15, 12),
      );
    });

    test('ignores names without a plausible date', () {
      for (final name in [
        'IMG_1234.JPG',
        'DSC00042.JPG',
        'photo.jpg',
        // Part of a longer number: an id, not a date.
        '1710512553000.jpg',
        'IMG_20241332_120000.jpg', // Month 13.
        'IMG_20230230_120000.jpg', // February 30.
        'IMG_19850101_120000.jpg', // Before 1990.
        'IMG_20271231_120000.jpg', // In the future.
      ]) {
        expect(parse(name), isNull, reason: name);
      }
    });
  });

  group('resolveCaptureDate', () {
    final platform = DateTime(2025, 6, 1, 9);

    test('metadata date first', () {
      final resolved = resolveCaptureDate(
        platformDate: platform,
        fromMetadata: true,
        fileName: 'IMG_20240315_142233.jpg',
        now: now,
      );
      expect(resolved, (date: platform, source: DateSource.exif));
    });

    test('then the file name', () {
      final resolved = resolveCaptureDate(
        platformDate: platform,
        fromMetadata: false,
        fileName: 'IMG-20240315-WA0001.jpg',
        now: now,
      );
      expect(resolved, (
        date: DateTime(2024, 3, 15, 12),
        source: DateSource.filename,
      ));
    });

    test('then the platform date', () {
      final resolved = resolveCaptureDate(
        platformDate: platform,
        fromMetadata: false,
        fileName: 'photo.jpg',
        now: now,
      );
      expect(resolved, (date: platform, source: DateSource.file));
    });
  });
}
