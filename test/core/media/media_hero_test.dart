import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  // The flight once landed at the top of the screen, then the photo jumped
  // to the middle (2026-11-08).
  testApp('a photo flies to its own frame, in the middle of the screen', (
    tester,
  ) async {
    // 4000 × 3000: on a 360 × 800 screen, the photo is 360 × 270, centered.
    await pumpTestApp(tester, media: FakeMediaSource(items: [testItem(1)]));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MediaThumbnail).first);
    await tester.pump();

    Rect? last;
    for (var i = 0; i < 11; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      final flying = find.byType(Image);
      if (flying.evaluate().length == 1) last = tester.getRect(flying);
    }
    expect(last, isNotNull);
    expect(last!.center.dy, closeTo(400, 6));
    expect(last.height / last.width, closeTo(0.75, 0.05));
    await tester.pumpAndSettle();
  });
}
