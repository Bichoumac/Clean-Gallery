import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Opens the precise color picker on [initial] (0xAARRGGBB) and returns the
/// color chosen, opaque, or `null` when cancelled.
Future<int?> showEditorColorPicker(BuildContext context, int initial) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => EditorColorPicker(initial: initial),
    );

/// `#RRGGBB` of [argb].
String hexOf(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// The opaque color written as [text] (`RRGGBB`, with or without `#`), or
/// `null` when it is not one.
int? parseHex(String text) {
  final digits = text.trim().replaceFirst('#', '');
  if (digits.length != 6) return null;
  final value = int.tryParse(digits, radix: 16);
  return value == null ? null : 0xFF000000 | value;
}

/// A color picker for the editor: a saturation and brightness square, a hue
/// bar, the old and new colors side by side, and the hex code to type an
/// exact color.
class EditorColorPicker extends StatefulWidget {
  /// Creates the picker on [initial] (0xAARRGGBB).
  const EditorColorPicker({required this.initial, super.key});

  /// Color shown first, kept as the "before" swatch.
  final int initial;

  @override
  State<EditorColorPicker> createState() => _EditorColorPickerState();
}

class _EditorColorPickerState extends State<EditorColorPicker> {
  late HSVColor _hsv = HSVColor.fromColor(Color(widget.initial));
  late final _hex = TextEditingController(text: hexOf(widget.initial));

  int get _argb => _hsv.toColor().toARGB32() | 0xFF000000;

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _set(HSVColor hsv) {
    setState(() => _hsv = hsv);
    _hex.text = hexOf(_argb);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String percent(double v) => '${(v * 100).round()} %';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.editorColorPicker, style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              Semantics(
                label: l10n.editorColorShade,
                value: '${percent(_hsv.saturation)}, ${percent(_hsv.value)}',
                increasedValue: percent((_hsv.value + 0.1).clamp(0, 1)),
                decreasedValue: percent((_hsv.value - 0.1).clamp(0, 1)),
                onIncrease: () =>
                    _set(_hsv.withValue((_hsv.value + 0.1).clamp(0, 1))),
                onDecrease: () =>
                    _set(_hsv.withValue((_hsv.value - 0.1).clamp(0, 1))),
                child: AspectRatio(
                  aspectRatio: 1.6,
                  child: _ShadeSquare(hsv: _hsv, onChanged: _set),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                label: l10n.editorColorHue,
                value: '${_hsv.hue.round()}°',
                increasedValue: '${((_hsv.hue + 10) % 360).round()}°',
                decreasedValue: '${((_hsv.hue + 350) % 360).round()}°',
                onIncrease: () => _set(_hsv.withHue((_hsv.hue + 10) % 360)),
                onDecrease: () => _set(_hsv.withHue((_hsv.hue + 350) % 360)),
                child: SizedBox(
                  height: 40,
                  child: _HueBar(hsv: _hsv, onChanged: _set),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Swatch(color: widget.initial, label: l10n.editorColorBefore),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                  _Swatch(color: _argb, label: l10n.editorColorAfter),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _hex,
                      decoration: InputDecoration(
                        labelText: l10n.editorColorHex,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[#0-9a-fA-F]'),
                        ),
                        LengthLimitingTextInputFormatter(7),
                      ],
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      onChanged: (text) {
                        final color = parseHex(text);
                        if (color != null) {
                          setState(
                            () => _hsv = HSVColor.fromColor(Color(color)),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_argb),
                    child: Text(l10n.editorColorUse),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Saturation (left to right) and brightness (bottom to top) of the hue of
/// [hsv]; drag or tap to pick.
class _ShadeSquare extends StatelessWidget {
  const _ShadeSquare({required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      void pick(Offset local) => onChanged(
        hsv
            .withSaturation((local.dx / box.maxWidth).clamp(0, 1))
            .withValue((1 - local.dy / box.maxHeight).clamp(0, 1)),
      );
      final pure = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => pick(d.localPosition),
        onPanUpdate: (d) => pick(d.localPosition),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.white, pure]),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                  ),
                ),
              ),
              Positioned(
                left: hsv.saturation * box.maxWidth - 12,
                top: (1 - hsv.value) * box.maxHeight - 12,
                child: _Thumb(color: hsv.toColor()),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Every hue from red back to red; drag or tap to pick.
class _HueBar extends StatelessWidget {
  const _HueBar({required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      void pick(Offset local) =>
          onChanged(hsv.withHue((local.dx / box.maxWidth).clamp(0, 1) * 359.9));
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => pick(d.localPosition),
        onPanUpdate: (d) => pick(d.localPosition),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [
                    for (var h = 0; h <= 360; h += 60)
                      HSVColor.fromAHSV(1, h % 360, 1, 1).toColor(),
                  ],
                ),
              ),
            ),
            Positioned(
              left: hsv.hue / 360 * box.maxWidth - 12,
              child: _Thumb(
                color: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// White ring showing the color under it.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
    ),
  );
}

/// A round swatch of [color] read as [label].
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label});

  final int color;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label ${hexOf(color)}',
    excludeSemantics: true,
    child: Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Color(color),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white38),
      ),
    ),
  );
}
