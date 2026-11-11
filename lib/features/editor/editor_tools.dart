import 'package:clean_gallery/core/widgets/steady_slider.dart';
import 'package:clean_gallery/domain/photo_edit.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Pencil and text colors, as 0xAARRGGBB.
const editorColors = [
  0xFFFFFFFF,
  0xFF000000,
  0xFFE8E24C, // The app's citron.
  0xFFFF453A,
  0xFFFFD60A,
  0xFF0A84FF,
];

/// Pencil widths, as fractions of the photo's shorter side.
const penWidths = [0.006, 0.014, 0.03];

/// Widths of blurred and pixelated areas: wider, as they cover faces or
/// plates.
const areaWidths = [0.04, 0.08, 0.14];

/// A slider of the editor: neutral, in the accent only when it [active]ly
/// changes the photo, so the accent always says what is being edited.
///
/// The [SliderTheme] is always there, only its colors change: adding it
/// when the value leaves zero would rebuild the slider and end the drag.
class _ToolSlider extends StatelessWidget {
  const _ToolSlider({required this.active, required this.child});

  final bool active;
  final SteadySlider child;

  @override
  Widget build(BuildContext context) {
    final theme = SliderTheme.of(context);
    return SliderTheme(
      data: active
          ? theme
          : theme.copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white12,
            ),
      child: child,
    );
  }
}

/// A row of chips that scrolls sideways.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final child in children)
          Padding(padding: const EdgeInsets.only(right: 8), child: child),
      ],
    ),
  );
}

/// A row of round color swatches, with an optional "none" first.
class ColorRow extends StatelessWidget {
  /// Creates the row; [selected] `null` is "none" when [allowNone].
  const ColorRow({
    required this.selected,
    required this.onSelected,
    required this.label,
    this.allowNone = false,
    super.key,
  });

  /// Color picked, or `null` for none.
  final int? selected;

  /// Called with the color picked, or `null` for none.
  final ValueChanged<int?> onSelected;

  /// Name of the row, read by TalkBack.
  final String label;

  /// Whether the first swatch is "none".
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    Widget swatch(int? color, String name) {
      final picked = color == selected;
      return Semantics(
        button: true,
        selected: picked,
        label: '$label, $name',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => onSelected(color),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color == null ? Colors.transparent : Color(color),
              shape: BoxShape.circle,
              border: Border.all(
                color: picked ? accent : Colors.white38,
                width: picked ? 3 : 1,
              ),
            ),
            child: color == null
                ? const Icon(
                    Icons.block_rounded,
                    size: 18,
                    color: Colors.white70,
                  )
                : null,
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (allowNone) swatch(null, l10n.editorNoBackground),
        for (final (i, color) in editorColors.indexed)
          swatch(color, l10n.editorPenColor(i + 1)),
      ],
    );
  }
}

/// Crop shapes, straightening, rotate and flip.
class CropTools extends StatelessWidget {
  /// Creates the tools.
  const CropTools({
    required this.ratio,
    required this.angle,
    required this.onRatio,
    required this.onAngle,
    required this.onRotate,
    required this.onFlip,
    super.key,
  });

  /// Shape picked.
  final CropRatio ratio;

  /// Straightening, in degrees.
  final double angle;

  /// Picks a shape.
  final ValueChanged<CropRatio> onRatio;

  /// Straightens.
  final ValueChanged<double> onAngle;

  /// Turns a quarter.
  final VoidCallback onRotate;

  /// Mirrors.
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChipRow(
          children: [
            for (final shape in CropRatio.values)
              ChoiceChip(
                label: Text(switch (shape) {
                  CropRatio.free => l10n.editorRatioFree,
                  CropRatio.original => l10n.editorRatioOriginal,
                  CropRatio.square => l10n.editorRatioSquare,
                  CropRatio.fourThree => l10n.editorRatio43,
                  CropRatio.threeFour => l10n.editorRatio34,
                  CropRatio.sixteenNine => l10n.editorRatio169,
                  CropRatio.nineSixteen => l10n.editorRatio916,
                }),
                selected: ratio == shape,
                showCheckmark: false,
                onSelected: (_) => onRatio(shape),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.straighten_rounded, size: 20),
              Expanded(
                child: _ToolSlider(
                  active: angle != 0,
                  child: SteadySlider(
                    value: angle,
                    min: -45,
                    max: 45,
                    steps: 180,
                    label: '${angle.toStringAsFixed(1)}°',
                    semanticFormatterCallback: (v) =>
                        '${l10n.editorStraighten} ${v.toStringAsFixed(1)}°',
                    onChanged: onAngle,
                  ),
                ),
              ),
              // Tap the value to straighten no more.
              TextButton(
                onPressed: angle == 0 ? null : () => onAngle(0),
                child: Text('${angle.toStringAsFixed(1)}°'),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: onRotate,
              icon: const Icon(Icons.rotate_90_degrees_cw_rounded),
              label: Text(l10n.editorRotate),
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: onFlip,
              icon: const Icon(Icons.flip_rounded),
              label: Text(l10n.editorFlip),
            ),
          ],
        ),
      ],
    );
  }
}

/// Enhance, the adjustments as chips, and the slider of the one picked.
class AdjustTools extends StatelessWidget {
  /// Creates the tools.
  const AdjustTools({
    required this.adjustments,
    required this.selected,
    required this.onSelected,
    required this.onChanged,
    required this.onEnhance,
    super.key,
  });

  /// Current adjustments.
  final Adjustments adjustments;

  /// Adjustment the slider sets.
  final Adjustment selected;

  /// Picks the adjustment for the slider.
  final ValueChanged<Adjustment> onSelected;

  /// Sets the picked adjustment.
  final ValueChanged<double> onChanged;

  /// Sets brightness and contrast from the photo's histogram.
  final VoidCallback onEnhance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String label(Adjustment a) => switch (a) {
      Adjustment.brightness => l10n.editorBrightness,
      Adjustment.contrast => l10n.editorContrast,
      Adjustment.saturation => l10n.editorSaturation,
      Adjustment.exposure => l10n.editorExposure,
      Adjustment.warmth => l10n.editorWarmth,
      Adjustment.vignette => l10n.editorVignette,
    };
    final value = selected.of(adjustments);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _ToolSlider(
                  active: value != 0,
                  child: SteadySlider(
                    value: value,
                    min: -1,
                    steps: 200,
                    label: '${(value * 100).round()}',
                    semanticFormatterCallback: (v) =>
                        '${label(selected)} ${(v * 100).round()}',
                    onChanged: onChanged,
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${(value * 100).round()}',
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        _ChipRow(
          children: [
            ActionChip(
              avatar: const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: Text(l10n.editorEnhance),
              onPressed: onEnhance,
            ),
            for (final a in Adjustment.values)
              ChoiceChip(
                avatar: Icon(switch (a) {
                  Adjustment.brightness => Icons.brightness_6_rounded,
                  Adjustment.contrast => Icons.contrast_rounded,
                  Adjustment.saturation => Icons.palette_outlined,
                  Adjustment.exposure => Icons.exposure_rounded,
                  Adjustment.warmth => Icons.thermostat_rounded,
                  Adjustment.vignette => Icons.vignette_rounded,
                }, size: 18),
                // A dot marks adjustments in use.
                label: Text(
                  a.of(adjustments) == 0 ? label(a) : '${label(a)} •',
                ),
                selected: a == selected,
                showCheckmark: false,
                onSelected: (_) => onSelected(a),
              ),
          ],
        ),
      ],
    );
  }
}

/// The filters as thumbnails of the photo, and the strength of the one
/// picked.
class FilterTools extends StatelessWidget {
  /// Creates the tools.
  const FilterTools({
    required this.filter,
    required this.strength,
    required this.thumbnail,
    required this.onFilter,
    required this.onStrength,
    super.key,
  });

  /// Filter picked.
  final PhotoFilter filter;

  /// Its strength, 0 to 1.
  final double strength;

  /// The photo with a filter, fitted in a square of the given side.
  final Widget Function(PhotoFilter filter, double side) thumbnail;

  /// Picks a filter.
  final ValueChanged<PhotoFilter> onFilter;

  /// Sets the strength.
  final ValueChanged<double> onStrength;

  /// Side of a thumbnail.
  static const double side = 64;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    String label(PhotoFilter f) => switch (f) {
      PhotoFilter.none => l10n.editorFilterNone,
      PhotoFilter.blackAndWhite => l10n.editorFilterBlackAndWhite,
      PhotoFilter.sepia => l10n.editorFilterSepia,
      PhotoFilter.vintage => l10n.editorFilterVintage,
      PhotoFilter.warm => l10n.editorFilterWarm,
      PhotoFilter.cool => l10n.editorFilterCool,
      PhotoFilter.vivid => l10n.editorFilterVivid,
      PhotoFilter.fade => l10n.editorFilterFade,
      PhotoFilter.dramatic => l10n.editorFilterDramatic,
      PhotoFilter.noir => l10n.editorFilterNoir,
      PhotoFilter.soft => l10n.editorFilterSoft,
    };
    final percent = (strength * 100).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Kept when no filter is picked, so the photo does not jump.
        Visibility.maintain(
          visible: filter != PhotoFilter.none,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _ToolSlider(
                    active: true,
                    child: SteadySlider(
                      value: strength,
                      steps: 100,
                      label: '$percent',
                      semanticFormatterCallback: (v) =>
                          '${l10n.editorFilterStrength} ${(v * 100).round()}',
                      onChanged: onStrength,
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text('$percent', textAlign: TextAlign.end),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: side + 28,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final f in PhotoFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Semantics(
                    button: true,
                    selected: f == filter,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onFilter(f),
                      child: Column(
                        children: [
                          Container(
                            width: side,
                            height: side,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: f == filter
                                    ? colors.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: thumbnail(f, side - 8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label(f),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: f == filter ? colors.primary : null,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Brush (pen, blur, pixelate), color, width and Undo.
class DrawTools extends StatelessWidget {
  /// Creates the tools.
  const DrawTools({
    required this.kind,
    required this.color,
    required this.widthIndex,
    required this.canUndo,
    required this.onKind,
    required this.onColor,
    required this.onWidth,
    required this.onUndo,
    super.key,
  });

  /// Brush picked.
  final StrokeKind kind;

  /// Pen color.
  final int color;

  /// Index of the width picked, in [penWidths] or [areaWidths].
  final int widthIndex;

  /// Whether there is a line to undo.
  final bool canUndo;

  /// Picks a brush.
  final ValueChanged<StrokeKind> onKind;

  /// Picks a pen color.
  final ValueChanged<int> onColor;

  /// Picks a width.
  final ValueChanged<int> onWidth;

  /// Removes the last line.
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<StrokeKind>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: StrokeKind.pen,
                icon: const Icon(Icons.edit_rounded),
                label: Text(l10n.editorBrushPen),
              ),
              ButtonSegment(
                value: StrokeKind.blur,
                icon: const Icon(Icons.blur_on_rounded),
                label: Text(l10n.editorBrushBlur),
              ),
              ButtonSegment(
                value: StrokeKind.pixelate,
                icon: const Icon(Icons.grid_on_rounded),
                label: Text(l10n.editorBrushPixelate),
              ),
            ],
            selected: {kind},
            onSelectionChanged: (kinds) => onKind(kinds.single),
          ),
          const SizedBox(height: 8),
          if (kind == StrokeKind.pen)
            ColorRow(
              selected: color,
              label: l10n.editorTextColor,
              onSelected: (c) => onColor(c!),
            ),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                IconButton(
                  tooltip: l10n.editorPenWidth(i + 1),
                  isSelected: i == widthIndex,
                  onPressed: () => onWidth(i),
                  icon: Icon(Icons.circle, size: 8.0 + i * 7),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: canUndo ? onUndo : null,
                icon: const Icon(Icons.undo_rounded),
                label: Text(l10n.editorUndoStroke),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Adding texts, and the style of the one selected: font, bold, size,
/// color, background, delete.
class TextTools extends StatelessWidget {
  /// Creates the tools for [selected] (`null`: none selected).
  const TextTools({
    required this.selected,
    required this.onAdd,
    required this.onEdit,
    required this.onChange,
    required this.onDelete,
    super.key,
  });

  /// The text selected, or `null`.
  final TextItem? selected;

  /// Adds a text.
  final VoidCallback onAdd;

  /// Changes the words of the selected text.
  final VoidCallback onEdit;

  /// Restyles the selected text.
  final ValueChanged<TextItem> onChange;

  /// Removes the selected text.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = selected;
    if (text == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.editorSelectText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.editorAddText),
            ),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChipRow(
          children: [
            ActionChip(
              avatar: const Icon(Icons.edit_note_rounded, size: 18),
              label: Text(l10n.editorEditText),
              onPressed: onEdit,
            ),
            for (final font in TextFont.values)
              ChoiceChip(
                label: Text(
                  switch (font) {
                    TextFont.sans => l10n.editorFontSans,
                    TextFont.serif => l10n.editorFontSerif,
                    TextFont.mono => l10n.editorFontMono,
                    TextFont.hand => l10n.editorFontHand,
                  },
                  style: TextStyle(
                    fontFamily: switch (font) {
                      TextFont.sans => 'Manrope',
                      TextFont.serif => 'serif',
                      TextFont.mono => 'monospace',
                      TextFont.hand => 'cursive',
                    },
                  ),
                ),
                selected: text.font == font,
                showCheckmark: false,
                onSelected: (_) => onChange(text.copyWith(font: font)),
              ),
            FilterChip(
              label: Text(l10n.editorBold),
              selected: text.bold,
              onSelected: (bold) => onChange(text.copyWith(bold: bold)),
            ),
            ActionChip(
              avatar: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(l10n.editorDeleteText),
              onPressed: onDelete,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.format_size_rounded, size: 20),
              Expanded(
                child: _ToolSlider(
                  active: false,
                  child: SteadySlider(
                    value: text.size,
                    min: 0.02,
                    max: 0.2,
                    semanticFormatterCallback: (v) =>
                        '${l10n.editorTextSize} ${(v * 100).round()}',
                    onChanged: (size) => onChange(text.copyWith(size: size)),
                  ),
                ),
              ),
            ],
          ),
        ),
        ColorRow(
          selected: text.color,
          label: l10n.editorTextColor,
          onSelected: (c) => onChange(text.copyWith(color: c!)),
        ),
        const SizedBox(height: 6),
        ColorRow(
          selected: text.background,
          label: l10n.editorTextBackground,
          allowNone: true,
          onSelected: (c) => onChange(
            c == null
                ? text.copyWith(background: null)
                : text.copyWith(background: c),
          ),
        ),
      ],
    );
  }
}
