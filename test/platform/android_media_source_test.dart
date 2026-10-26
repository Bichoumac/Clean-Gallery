import 'package:clean_gallery/platform/android/android_media_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AndroidMediaSource.hasMetadataDate', () {
    const added = 1700000000;
    const modified = 1700000500;

    test('unset DATE_TAKEN is not a metadata date', () {
      expect(
        AndroidMediaSource.hasMetadataDate(
          dateTaken: 0,
          addedSeconds: added,
          modifiedSeconds: modified,
        ),
        isFalse,
      );
    });

    test('a DATE_TAKEN copied from the file dates is not trusted', () {
      for (final copied in [added * 1000 + 999, modified * 1000 - 1500]) {
        expect(
          AndroidMediaSource.hasMetadataDate(
            dateTaken: copied,
            addedSeconds: added,
            modifiedSeconds: modified,
          ),
          isFalse,
        );
      }
    });

    test('a DATE_TAKEN of its own is a metadata date', () {
      expect(
        AndroidMediaSource.hasMetadataDate(
          dateTaken: (added - 86400) * 1000,
          addedSeconds: added,
          modifiedSeconds: modified,
        ),
        isTrue,
      );
    });
  });
}
