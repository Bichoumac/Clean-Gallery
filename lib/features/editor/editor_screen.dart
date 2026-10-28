import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:clean_gallery/analysis/color_matrix.dart';
import 'package:clean_gallery/core/media/media_actions.dart';
import 'package:clean_gallery/core/media/media_index.dart';
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

/// The editor's tools.
enum EditorTool {
  /// Crop, rotate and flip.
  crop,

  /// Color adjustments.
  adjust,

  /// Pencil.
  draw,
}

/// Pencil colors, as 0xAARRGGBB.
const penColors = [
  0xFFFFFFFF,
  0xFF000000,
  0xFFC6F432, // The app's lime.
  0xFFFF453A,
  0xFFFFD60A,
  0xFF0A84FF,
];

/// Pencil widths, as fractions of the photo's shorter side.
const penWidths = [0.006, 0.014, 0.03];

/// How a photo is saved from the editor.
enum SaveMode {
  /// A new photo next to the original, which stays.
  copy,

  /// A new photo, and the original moved to the app trash.
  replace,
}

/// Full-screen photo editor, above the tabs: crop with handles and fixed
/// shapes, rotate, flip, color adjustments and a pencil, previewed live,
/// then saved as a new photo. Dark like the viewer, without ads.
///
/// The preview paints the decoded screen-sized image directly with the
/// edit's transform and color matrix ([paintEdit]): moving a slider only
/// repaints, never decodes or lays out again. Closing with changes asks
/// first. Pops with the id of the saved photo. See
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
  int _penColor = penColors[2];
  double _penWidth = penWidths[1];
  bool _saving = false;

  /// The preview, decoded once.
  ui.Image? _image;
  ImageStream? _stream;
  late final _listener = ImageStreamListener(
    (info, _) => setState(() => _image = info.image),
    onError: (_, _) {},
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = ref
        .read(mediaSourceProvider)
        .preview(
          widget.photo,
          longestSide: viewerPreviewSide(context, widget.photo),
        );
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key != _stream?.key) {
      _stream?.removeListener(_listener);
      _stream = stream..addListener(_listener);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

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
    if (_saving) return;
    final edit = ref.read(photoEditorProvider(widget.photo)).edit;
    if (edit.isIdentity || await _confirmDiscard()) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// Asks how to save, then saves; pops with the new photo's id.
  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final mode = await showModalBottomSheet<SaveMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.library_add_outlined),
              title: Text(l10n.editorSaveCopy),
              subtitle: Text(l10n.editorSaveCopyBody),
              onTap: () => Navigator.of(context).pop(SaveMode.copy),
            ),
            ListTile(
              leading: const Icon(Icons.published_with_changes_rounded),
              title: Text(l10n.editorSaveReplace),
              subtitle: Text(l10n.editorSaveReplaceBody),
              onTap: () => Navigator.of(context).pop(SaveMode.replace),
            ),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final edit = ref.read(photoEditorProvider(widget.photo)).edit;
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(platformBridgeProvider)
          .saveEditedPhoto(
            widget.photo,
            edit,
            colorMatrix: adjustmentMatrix(edit.adjustments),
          );
      await ref.read(mediaIndexProvider.notifier).sync();
      if (mode == SaveMode.replace) {
        await ref.read(mediaActionsProvider).trash([widget.photo]);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            mode == SaveMode.copy
                ? l10n.editorSavedCopy
                : l10n.editorSavedReplace,
          ),
        ),
      );
      navigator.pop(id);
    } on PlatformException {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.editorSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final photo = widget.photo;
    final state = ref.watch(photoEditorProvider(photo));
    final editor = ref.read(photoEditorProvider(photo).notifier);
    final edit = state.edit;
    final image = _image;

    return Theme(
      data: AppTheme.dark(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: PopScope(
          canPop: edit.isIdentity && !_saving,
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
                IconButton(
                  tooltip: l10n.editorReset,
                  onPressed: edit.isIdentity || _saving ? null : editor.reset,
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton(
                    onPressed: edit.isIdentity || _saving ? null : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.editorSave),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: AbsorbPointer(
                absorbing: _saving,
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: image == null
                            ? const Center(child: CircularProgressIndicator())
                            : LayoutBuilder(
                                builder: (context, box) => switch (_tool) {
                                  EditorTool.crop => _CropView(
                                    image: image,
                                    edit: edit,
                                    area: box.biggest,
                                    onDrag: editor.dragCrop,
                                  ),
                                  EditorTool.adjust => _ResultView(
                                    image: image,
                                    edit: edit,
                                    area: box.biggest,
                                  ),
                                  EditorTool.draw => _ResultView(
                                    image: image,
                                    edit: edit,
                                    area: box.biggest,
                                    onStart: (point) => editor.startStroke(
                                      point,
                                      color: _penColor,
                                      width: _penWidth,
                                    ),
                                    onExtend: editor.extendStroke,
                                  ),
                                },
                              ),
                      ),
                    ),
                    switch (_tool) {
                      EditorTool.crop => _CropTools(
                        ratio: state.ratio,
                        onRatio: editor.setRatio,
                        onRotate: editor.rotate,
                        onFlip: editor.flip,
                      ),
                      EditorTool.adjust => _AdjustTools(
                        adjustments: edit.adjustments,
                        selected: _adjustment,
                        onSelected: (a) => setState(() => _adjustment = a),
                        onChanged: (value) => editor.adjust(_adjustment, value),
                      ),
                      EditorTool.draw => _DrawTools(
                        color: _penColor,
                        width: _penWidth,
                        canUndo: edit.strokes.isNotEmpty,
                        onColor: (c) => setState(() => _penColor = c),
                        onWidth: (w) => setState(() => _penWidth = w),
                        onUndo: editor.undoStroke,
                      ),
                    },
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
                          ButtonSegment(
                            value: EditorTool.draw,
                            icon: const Icon(Icons.edit_rounded),
                            label: Text(l10n.editorDraw),
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
      ),
    );
  }
}

/// Size of a box of [ratio] (width / height) fitted in [area].
Size _fit(double ratio, Size area) => ratio >= area.width / area.height
    ? Size(area.width, area.width / ratio)
    : Size(area.height * ratio, area.height);

/// Width divided by height of [image] once turned by [edit].
double _orientedRatio(ui.Image image, PhotoEdit edit) =>
    edit.orientedRatio(image.width, image.height);

/// Paints [image] edited by [edit] into [size], showing the part [view] of
/// the rotated photo (fractions): the whole photo while cropping, the crop
/// otherwise. Turns, flips, colors and draws in the order the native save
/// does (`PhotoSaver.kt`), so the saved photo matches.
void paintEdit(
  Canvas canvas,
  Size size,
  ui.Image image,
  PhotoEdit edit, {
  required CropRect view,
}) {
  // The whole rotated photo, placed so that [view] fills [size].
  final full = Size(size.width / view.width, size.height / view.height);
  final origin = Offset(-view.left * full.width, -view.top * full.height);
  canvas
    ..save()
    ..clipRect(Offset.zero & size)
    ..translate(origin.dx, origin.dy)
    ..save()
    ..translate(full.width / 2, full.height / 2);
  if (edit.flipped) canvas.scale(-1, 1);
  canvas.rotate(edit.quarterTurns * math.pi / 2);
  // Before turning, the photo's own width is the rotated height.
  final turned = edit.quarterTurns.isOdd;
  final drawn = turned ? Size(full.height, full.width) : full;
  final paint = Paint()
    ..filterQuality = FilterQuality.medium
    ..colorFilter = edit.adjustments.isNeutral
        ? null
        : ColorFilter.matrix(adjustmentMatrix(edit.adjustments));
  canvas
    ..drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(
        center: Offset.zero,
        width: drawn.width,
        height: drawn.height,
      ),
      paint,
    )
    ..restore();
  final shorter = math.min(full.width, full.height);
  for (final stroke in edit.strokes) {
    final pen = Paint()
      ..color = Color(stroke.color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke.width * shorter
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final path = Path();
    for (final (i, (x, y)) in stroke.points.indexed) {
      final point = Offset(x * full.width, y * full.height);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      // A single tap draws a dot.
      if (stroke.points.length == 1) path.lineTo(point.dx + 0.01, point.dy);
    }
    canvas.drawPath(path, pen);
  }
  canvas.restore();
}

/// Paints the edit, and the crop frame on top while cropping.
class _EditPainter extends CustomPainter {
  _EditPainter({
    required this.image,
    required this.edit,
    required this.view,
    this.frame,
  });

  final ui.Image image;
  final PhotoEdit edit;
  final CropRect view;

  /// The crop frame's accent color, or `null` for no frame.
  final Color? frame;

  @override
  void paint(Canvas canvas, Size size) {
    paintEdit(canvas, size, image, edit, view: view);
    if (frame case final accent?) _paintFrame(canvas, size, edit.crop, accent);
  }

  @override
  bool shouldRepaint(_EditPainter old) =>
      old.image != image ||
      old.edit != edit ||
      old.view != view ||
      old.frame != frame;
}

/// The crop frame: the outside dimmed, thirds lines, lime corners.
void _paintFrame(Canvas canvas, Size size, CropRect crop, Color accent) {
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

/// The whole photo with the crop frame. Dragging inside moves the crop, a
/// corner resizes it.
class _CropView extends StatefulWidget {
  const _CropView({
    required this.image,
    required this.edit,
    required this.area,
    required this.onDrag,
  });

  final ui.Image image;
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
    final size = _fit(_orientedRatio(widget.image, widget.edit), widget.area);
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
          child: CustomPaint(
            size: size,
            painter: _EditPainter(
              image: widget.image,
              edit: widget.edit,
              view: CropRect.full,
              frame: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The result: only the cropped part, as large as it fits. With [onStart]
/// and [onExtend], a finger draws on it.
class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.image,
    required this.edit,
    required this.area,
    this.onStart,
    this.onExtend,
  });

  final ui.Image image;
  final PhotoEdit edit;
  final Size area;
  final ValueChanged<(double, double)>? onStart;
  final ValueChanged<(double, double)>? onExtend;

  @override
  Widget build(BuildContext context) {
    final crop = edit.crop;
    final ratio = _orientedRatio(image, edit) * crop.width / crop.height;
    final size = _fit(ratio, area);
    // A point of the view in fractions of the whole rotated photo.
    (double, double) toPhoto(Offset local) => (
      crop.left + local.dx / size.width * crop.width,
      crop.top + local.dy / size.height * crop.height,
    );
    final onStart = this.onStart;
    final onExtend = this.onExtend;
    final painted = CustomPaint(
      size: size,
      painter: _EditPainter(image: image, edit: edit, view: crop),
    );
    return Center(
      child: onStart == null || onExtend == null
          ? painted
          : Semantics(
              label: AppLocalizations.of(context).editorDrawArea,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => onStart(toPhoto(d.localPosition)),
                onPanUpdate: (d) => onExtend(toPhoto(d.localPosition)),
                child: painted,
              ),
            ),
    );
  }
}

/// Pencil colors and widths, and Undo.
class _DrawTools extends StatelessWidget {
  const _DrawTools({
    required this.color,
    required this.width,
    required this.canUndo,
    required this.onColor,
    required this.onWidth,
    required this.onUndo,
  });

  final int color;
  final double width;
  final bool canUndo;
  final ValueChanged<int> onColor;
  final ValueChanged<double> onWidth;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final (i, pen) in penColors.indexed)
                Semantics(
                  button: true,
                  selected: pen == color,
                  label: l10n.editorPenColor(i + 1),
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => onColor(pen),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(pen),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: pen == color ? colors.primary : Colors.white38,
                          width: pen == color ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (i, w) in penWidths.indexed)
                IconButton(
                  tooltip: l10n.editorPenWidth(i + 1),
                  isSelected: w == width,
                  onPressed: () => onWidth(w),
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
