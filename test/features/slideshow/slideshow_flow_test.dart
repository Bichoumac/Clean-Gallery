import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/slideshow.dart';
import 'package:clean_gallery/features/memories/memory_card.dart';
import 'package:clean_gallery/features/slideshow/slideshow_actions.dart';
import 'package:clean_gallery/features/slideshow/slideshow_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  final now = DateTime.now();

  FakeMediaSource source({List<int> yearsAgo = const []}) => FakeMediaSource(
    items: [
      for (var i = 1; i <= 4; i++)
        testItem(i, takenAt: now.subtract(Duration(minutes: i))),
      // Photos of this day, years ago, for a memory.
      for (final years in yearsAgo)
        for (var i = 0; i < 6; i++)
          testItem(
            1000 * years + i,
            takenAt: DateTime(now.year - years, now.month, now.day, 10, i),
          ),
    ],
  );

  /// Selects the Camera photos at [indexes], then More → Slideshow.
  Future<void> slideshowOfSelection(
    WidgetTester tester,
    List<int> indexes,
  ) async {
    final thumbs = find.byType(MediaThumbnail);
    await tester.longPress(thumbs.at(indexes.first));
    await tester.pumpAndSettle();
    for (final i in indexes.skip(1)) {
      await tester.tap(thumbs.at(i));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slideshow'));
    await tester.pumpAndSettle();
  }

  testApp('a selection plays after its options, then can be saved', (
    tester,
  ) async {
    final bridge = FakePlatformBridge();
    final music = FakeMusicPlayer()
      ..picked = const DeviceMusic(uri: 'content://song', name: 'Song.mp3');
    await pumpTestApp(tester, media: source(), bridge: bridge, music: music);
    await slideshowOfSelection(tester, [0, 2]);

    // The options sheet, with the defaults.
    expect(find.text('Time per photo'), findsOneWidget);
    await tester.tap(find.text('3 s'));
    await tester.ensureVisible(find.text('Choose a track on the phone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a track on the phone'));
    await tester.pumpAndSettle();
    expect(find.text('Song.mp3'), findsOneWidget);
    await tester.ensureVisible(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SlideshowScreen), findsOneWidget);
    expect(bridge.keepScreenOn, isTrue);
    expect(music.playing, isA<DeviceMusic>());

    // A tap shows the controls; pausing pauses the music.
    await tester.tapAt(const Offset(180, 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(music.paused, isTrue);
    await tester.tap(find.byTooltip('Play'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(music.paused, isFalse);

    // Both photos, 3 s each, then the end.
    await tester.pumpAndSettle();
    expect(find.text('Replay'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Today');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Save'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saved in Albums → Slideshows'), findsOneWidget);
    // Saved: not offered again.
    expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(SlideshowScreen), findsNothing);
    expect(bridge.keepScreenOn, isFalse);
    expect(music.playing, isNull);

    // Listed under Albums → Slideshows, playing again on a tap.
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slideshows'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    await tester.tap(find.text('Today'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SlideshowScreen), findsOneWidget);
    // Its own options: 3 s per photo, so 2 photos end within 7 s.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Replay'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testApp('a custom slideshow plays the album and period picked', (
    tester,
  ) async {
    final items = [
      for (var i = 1; i <= 4; i++)
        testItem(i, takenAt: now.subtract(Duration(minutes: i))),
    ];
    await pumpTestApp(
      tester,
      media: FakeMediaSource(
        items: items,
        folders: const [Album(id: 'trip', name: 'Trip', count: 2)],
        folderItems: {
          'trip': [items[0], items[2]],
        },
      ),
    );
    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slideshows'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Slideshow'));
    await tester.pumpAndSettle();

    // Every photo and video by default; pick the folder.
    expect(find.text('Album'), findsOneWidget);
    await tester.tap(find.byType(DropdownMenu<SlideshowAlbum?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trip').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SlideshowScreen), findsOneWidget);
    await tester.tapAt(const Offset(180, 400));
    await tester.pump(const Duration(milliseconds: 300));
    // Only the folder's two photos, in the last 30 days.
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('Trip · Last 30 days'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
  });

  testApp('a memory plays at once', (tester) async {
    await pumpTestApp(tester, media: source(yearsAgo: [1]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('On this day, 1 year ago'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SlideshowScreen), findsOneWidget);
  });

  testApp('a memory card plays, and ✕ dismisses it with Undo', (tester) async {
    await pumpTestApp(tester, media: source(yearsAgo: [1]));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryCard), findsOneWidget);
    expect(find.text('On this day, 1 year ago'), findsOneWidget);

    await tester.tap(find.text('On this day, 1 year ago'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SlideshowScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('6 of 6'), findsNothing);
    expect(find.text('Replay'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Dismiss this memory'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryCard), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryCard), findsOneWidget);
  });

  testApp('no memory card while memories are off in Settings', (tester) async {
    await pumpTestApp(tester, media: source(yearsAgo: [1]));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryCard), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Off'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // At the top of the screen, clear of the navigation bar.
    await tester.ensureVisible(find.text('Off'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Off'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Camera'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryCard), findsNothing);
  });
}
