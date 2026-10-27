import 'package:clean_gallery/features/viewer/zoomable_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  // A portrait phone screen: 1,080 × 2,340 physical pixels.
  Future<int> side(
    WidgetTester tester, {
    required int w,
    required int h,
  }) async {
    late int result;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(360, 780), devicePixelRatio: 3),
        child: Builder(
          builder: (context) {
            result = viewerPreviewSide(
              context,
              testItem(1).copyWith(width: w, height: h),
            );
            return const SizedBox();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('a landscape photo needs only the screen width', (tester) async {
    expect(await side(tester, w: 4000, h: 3000), 1080);
  });

  testWidgets('a portrait photo is bound by the width too', (tester) async {
    // 1,080 wide at 3:4 is 1,440 tall, within the 2,340 of the screen.
    expect(await side(tester, w: 3000, h: 4000), 1440);
  });

  testWidgets('a tall screenshot is bound by the screen height', (
    tester,
  ) async {
    expect(await side(tester, w: 1080, h: 4000), 2340);
  });

  testWidgets('a small photo is never enlarged', (tester) async {
    expect(await side(tester, w: 640, h: 480), 640);
  });
}
