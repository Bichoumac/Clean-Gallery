import 'package:flutter/material.dart';

/// The app's slider: the thumb stays under the finger, at any speed and from
/// any value.
///
/// A Material [Slider] with `divisions` animates its thumb towards each new
/// value with an ease, so a fast drag first lags then catches up. This one
/// is always continuous and rounds the value itself to [steps] equal steps
/// between [min] and [max], so the callbacks still receive whole steps.
///
/// Keep the widget tree around it stable while dragging: replacing an
/// ancestor (for example adding a [SliderTheme] once the value leaves zero)
/// recreates the slider and ends the drag.
class SteadySlider extends StatelessWidget {
  /// Creates the slider.
  const SteadySlider({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.steps,
    this.label,
    this.semanticFormatterCallback,
    this.onChangeStart,
    this.onChangeEnd,
    super.key,
  });

  /// Current value, clamped between [min] and [max].
  final double value;

  /// Called with each new value while dragging; `null` disables the slider.
  final ValueChanged<double>? onChanged;

  /// Lowest value.
  final double min;

  /// Highest value.
  final double max;

  /// Number of equal steps the values are rounded to; `null` for any value.
  final int? steps;

  /// Shown above the thumb while dragging; `null` for none.
  final String? label;

  /// What screen readers say for a value.
  final SemanticFormatterCallback? semanticFormatterCallback;

  /// Called when the finger lands.
  final ValueChanged<double>? onChangeStart;

  /// Called when the finger lifts.
  final ValueChanged<double>? onChangeEnd;

  /// [raw] rounded to the nearest step.
  @visibleForTesting
  double snap(double raw) {
    final steps = this.steps;
    if (steps == null || steps <= 0 || max <= min) return raw;
    final size = (max - min) / steps;
    return (min + ((raw - min) / size).round() * size).clamp(min, max);
  }

  ValueChanged<double>? _snapped(ValueChanged<double>? callback) =>
      callback == null ? null : (raw) => callback(snap(raw));

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        showValueIndicator: label == null
            ? ShowValueIndicator.never
            : ShowValueIndicator.onDrag,
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        label: label,
        semanticFormatterCallback: semanticFormatterCallback,
        onChangeStart: _snapped(onChangeStart),
        onChanged: _snapped(onChanged),
        onChangeEnd: _snapped(onChangeEnd),
      ),
    );
  }
}
