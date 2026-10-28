import 'dart:async';
import 'dart:math' as math;

import 'package:clean_gallery/analysis/color_matrix.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/theme/app_theme.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/photo_edit.dart';
import 'package:clean_gallery/features/editor/photo_editor.dart';
import 'package:clean_gallery/features/viewer/zoomable_image.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The editor's two tools.
enum EditorTool {
  /// Crop, rotate and flip.
  crop,

  /// Color adjustments.
  adjust,
}

/// Full-screen photo editor, above the tabs: crop with handles and fixed
/// shapes, rotate, flip, and color adjustments previewed live with a color
/// matrix on a screen-sized image, so moving a slider never re-encodes the
/// photo. Dark like the viewer, without ads.
///
/// Closing with changes asks first. Saving comes in part 3 of M6. See
/// `docs/features/editor.md`.
class EditorScreen extends ConsumerStatefulWidget {
  /// Creates the editor of [photo].
  const EditorScreen({required this.photo, super.key});

  /// The photo edited.
  final MediaItem photo;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  EditorTool _tool = EditorTool.crop;
  Adjustment _adjustment = Adjustment.brightness;

  /// Asks before dropping the changes; `true` to leave.
  Future<bool> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editorDiscardTitle),
        content: Text(l10n.editorDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.editorKeepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.editorDiscard),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _close() async {
    final edit = ref.read(photoEditorProvider(widget.photo)).edit;
    if (edit.isIdentity || await _confirmDiscard()) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final photo = widget.photo;
    final state = ref.watch(photoEditorProvider(photo));
    final editor = ref.read(photoEditorProvider(photo).notifier);
    final edit = state.edit;
    final image = ref
        .watch(mediaSourceProvider)
        .preview(photo, longestSide: viewerPreviewSide(context, photo));

    return Theme(
      data: AppTheme.dark(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: PopScope(
          canPop: edit.isIdentity,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_close());
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              leading: IconButton(
                tooltip: l10n.editorClose,
                icon: const Icon(Icons.close_rounded),
                onPressed: _close,
              ),
              title: Text(l10n.editorTitle),
              actions: [
                TextButton(
                  onPressed: edit.isIdentity ? null : editor.reset,
                  child: Text(l10n.editorReset),
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: LayoutBuilder(
                        builder: (context, box) => _tool == EditorTool.crop
                            ? _CropView(
                                image: image,
                                photo: photo,
                                edit: edit,
                                area: box.biggest,
                                onDrag: editor.dragCrop,
                              )
                            : _CroppedView(
                                image: image,
                                photo: photo,
                                edit: edit,
                                area: box.biggest,
                              ),
                      ),
                    ),
                  ),
                  if (_tool == EditorTool.crop)
                    _CropTools(
                      ratio: state.ratio,
                      onRatio: editor.setRatio,
                      onRotate: editor.rotate,
                      onFlip: editor.flip,
                    )
                  else
                    _AdjustTools(
                      adjustments: edit.adjustments,
                      selected: _adjustment,
                      onSelected: (a) => setState(() => _adjustment = a),
                      onChanged: (value) => editor.adjust(_adjustment, value),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SegmentedButton<EditorTool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: EditorTool.crop,
                          icon: const Icon(Icons.crop_rotate_rounded),
                          label: Text(l10n.editorCrop),
                        ),
                        ButtonSegment(
                          value: EditorTool.adjust,
                          icon: const Icon(Icons.tune_rounded),
                          label: Text(l10n.editorAdjust),
                        ),
                      ],
                      selected: {_tool},
                      onSelectionChanged: (tools) =>
                          setState(() => _tool = tools.single),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Size of the photo rotated by [edit], fitted in [area].
Size _fitted(MediaItem photo, PhotoEdit edit, Size area, {double? ratio}) {
  final r = ratio ?? edit.orientedRatio(photo.width, photo.height);
  return r >= area.width / area.height
      ? Size(area.width, area.width / r)
      : Size(area.height * r, area.height);
}

/// [image] rotated and flipped as in [edit], stretched to its box, with
/// the colors of [edit]'s adjustments.
Widget _orientedImage(ImageProvider image, PhotoEdit edit) {
  Widget child = RotatedBox(
    quarterTurns: edit.quarterTurns,
    child: Image(image: image, fit: BoxFit.fill, gaplessPlayback: true),
  );
  if (edit.flipped) child = Transform.flip(flipX: true, child: child);
  if (!edit.adjustments.isNeutral) {
    child = ColorFiltered(
      colorFilter: ColorFilter.matrix(adjustmentMatrix(edit.adjustments)),
      child: child,
    );
  }
  return child;
}

/// The whole photo with the crop on top: the outside dimmed, thirds lines,
/// corner handles. Dragging inside moves the crop, a corner resizes it.
class _CropView extends StatefulWidget {
  const _CropView({
    required this.image,
    required this.photo,
    required this.edit,
    required this.area,
    required this.onDrag,
  });

  final ImageProvider image;
  final MediaItem photo;
  final PhotoEdit edit;
  final Size area;
  final void Function(CropHandle handle, double dx, double dy) onDrag;

  @override
  State<_CropView> createState() => _CropViewState();
}

/// Distance from a corner within which a touch grabs it.
const _handleReach = 36.0;

class _CropViewState extends State<_CropView> {
  CropHandle? _handle;

  CropHandle? _handleAt(Offset point, Size size) {
    final crop = widget.edit.crop;
    final corners = {
      CropHandle.topLeft: Offset(crop.left, crop.top),
      CropHandle.topRight: Offset(crop.right, crop.top),
      CropHandle.bottomLeft: Offset(crop.left, crop.bottom),
      CropHandle.bottomRight: Offset(crop.right, crop.bottom),
    };
    for (final MapEntry(key: handle, value: corner) in corners.entries) {
      final at = Offset(corner.dx * size.width, corner.dy * size.height);
      if ((at - point).distance <= _handleReach) return handle;
    }
    final inside = Rect.fromLTRB(
      crop.left * size.width,
      crop.top * size.height,
      crop.right * size.width,
      crop.bottom * size.height,
    ).contains(point);
    return inside ? CropHandle.inside : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = _fitted(widget.photo, widget.edit, widget.area);
    return Center(
      child: Semantics(
        label: l10n.editorCropArea,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) =>
              _handle = _handleAt(details.localPosition, size),
          onPanUpdate: (details) {
            final handle = _handle;
            if (handle == null) return;
            widget.onDrag(
              handle,
              details.delta.dx / size.width,
              details.delta.dy / size.height,
            );
          },
          onPanEnd: (_) => _handle = null,
          child: SizedBox.fromSize(
            size: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _orientedImage(widget.image, widget.edit),
                CustomPaint(
                  painter: _CropPainter(
                    crop: widget.edit.crop,
                    accent: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter({required this.crop, required this.accent});

  final CropRect crop;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      crop.left * size.width,
      crop.top * size.height,
      crop.right * size.width,
      crop.bottom * size.height,
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRect(rect),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
    final thin = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = rect.left + rect.width * i / 3;
      final y = rect.top + rect.height * i / 3;
      canvas
        ..drawLine(Offset(x, rect.top), Offset(x, rect.bottom), thin)
        ..drawLine(Offset(rect.left, y), Offset(rect.right, y), thin);
    }
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final corner = Paint()
      ..color = accent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final arm = math.min(20, math.min(rect.width, rect.height) / 3).toDouble();
    for (final (x, y, sx, sy) in [
      (rect.left, rect.top, 1.0, 1.0),
      (rect.right, rect.top, -1.0, 1.0),
      (rect.left, rect.bottom, 1.0, -1.0),
      (rect.right, rect.bottom, -1.0, -1.0),
    ]) {
      canvas
        ..drawLine(Offset(x, y), Offset(x + arm * sx, y), corner)
        ..drawLine(Offset(x, y), Offset(x, y + arm * sy), corner);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.crop != crop || old.accent != accent;
}

/// Only the cropped part, as large as it fits: the result of the edit.
class _CroppedView extends StatelessWidget {
  const _CroppedView({
    required this.image,
    required this.photo,
    required this.edit,
    required this.area,
  });

  final ImageProvider image;
  final MediaItem photo;
  final PhotoEdit edit;
  final Size area;

  @override
  Widget build(BuildContext context) {
    final crop = edit.crop;
    final ratio = edit.orientedRatio(photo.width, photo.height);
    final shown = _fitted(
      photo,
      edit,
      area,
      ratio: crop.width * ratio / crop.height,
    );
    final full = Size(shown.width / crop.width, shown.height / crop.height);
    return Center(
      child: SizedBox.fromSize(
        size: shown,
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -crop.left * full.width,
                top: -crop.top * full.height,
                width: full.width,
                height: full.height,
                child: _orientedImage(image, edit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Crop shapes, rotate and flip.
class _CropTools extends StatelessWidget {
  const _CropTools({
    required this.ratio,
    required this.onRatio,
    required this.onRotate,
    required this.onFlip,
  });

  final CropRatio ratio;
  final ValueChanged<CropRatio> onRatio;
  final VoidCallback onRotate;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final shape in CropRatio.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
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

/// The five adjustments as chips, and the slider of the one picked.
class _AdjustTools extends StatelessWidget {
  const _AdjustTools({
    required this.adjustments,
    required this.selected,
    required this.onSelected,
    required this.onChanged,
  });

  final Adjustments adjustments;
  final Adjustment selected;
  final ValueChanged<Adjustment> onSelected;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String label(Adjustment a) => switch (a) {
      Adjustment.brightness => l10n.editorBrightness,
      Adjustment.contrast => l10n.editorContrast,
      Adjustment.saturation => l10n.editorSaturation,
      Adjustment.exposure => l10n.editorExposure,
      Adjustment.warmth => l10n.editorWarmth,
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
                child: Slider(
                  value: value,
                  min: -1,
                  divisions: 200,
                  label: '${(value * 100).round()}',
                  semanticFormatterCallback: (v) =>
                      '${label(selected)} ${(v * 100).round()}',
                  onChanged: onChanged,
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
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final a in Adjustment.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(switch (a) {
                      Adjustment.brightness => Icons.brightness_6_rounded,
                      Adjustment.contrast => Icons.contrast_rounded,
                      Adjustment.saturation => Icons.palette_outlined,
                      Adjustment.exposure => Icons.exposure_rounded,
                      Adjustment.warmth => Icons.thermostat_rounded,
                    }, size: 18),
                    // A dot marks adjustments in use.
                    label: Text(
                      a.of(adjustments) == 0 ? label(a) : '${label(a)} •',
                    ),
                    selected: a == selected,
                    showCheckmark: false,
                    onSelected: (_) => onSelected(a),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
