import 'package:clean_gallery/core/widgets/steady_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SteadySlider slider({int? steps, double min = 0, double max = 1}) =>
      SteadySlider(
        value: 0,
        min: min,
        max: max,
        steps: steps,
        onChanged: (_) {},
      );

  test('values are rounded to the nearest step, within the range', () {
    final angle = slider(steps: 180, min: -45, max: 45);
    expect(angle.snap(0.26), closeTo(0.5, 1e-9));
    expect(angle.snap(-0.24), closeTo(0, 1e-9));
    expect(angle.snap(50), 45);
    final days = slider(steps: 89, min: 1, max: 90);
    expect(days.snap(29.6), closeTo(30, 1e-9));
    expect(slider().snap(0.123), 0.123);
  });

  testWidgets('the slider is continuous, so its thumb is never animated', (
    tester,
  ) async {
    final values = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SteadySlider(
            value: 0,
            min: -1,
            steps: 200,
            onChanged: values.add,
          ),
        ),
      ),
    );
    final material = tester.widget<Slider>(find.byType(Slider));
    expect(material.divisions, isNull);
    await tester.drag(find.byType(Slider), const Offset(60, 0));
    expect(values, isNotEmpty);
    for (final v in values) {
      expect((v * 100).roundToDouble(), closeTo(v * 100, 1e-6));
    }
  });
}
