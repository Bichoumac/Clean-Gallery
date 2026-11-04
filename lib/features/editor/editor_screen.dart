import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:clean_gallery/analysis/enhance.dart';
import 'package:clean_gallery/core/media/media_actions.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/theme/app_theme.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/photo_edit.dart';
import 'package:clean_gallery/features/editor/edit_painter.dart';
import 'package:clean_gallery/features/editor/editor_tools.dart';
import 'package:clean_gallery/features/editor/photo_editor.dart';
import 'package:clean_gallery/features/viewer/zoomable_image.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The editor's tools.
enum EditorTool {
  /// Crop, straighten, rotate and flip.
  crop,

  /// Preset looks.
  filter,

  /// Enhance, color adjustments and vignette.
  adjust,

  /// Pencil, blur and pixelate.
  draw,

  /// Texts.
  text,
}

/// How a photo is saved from the editor.
enum SaveMode {
  /// A new photo next to the original, which stays.
  copy,

  /// A new photo, and the original moved to the app trash.
  replace,
}

/// Largest photo rendered when saving: 40 megapixels, about 160 MB of
/// pixels. Larger photos are saved smaller.
const maxSavedPixels = 40000000;

/// Longest side rendered when saving, within the GPU's texture limit.
const maxSavedSide = 8192;

/// Decodes [provider] into one image.
Future<ui.Image> decodeImage(ImageProvider provider) {
  final completer = Completer<ui.Image>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      completer.complete(info.image);
    },
    onError: (error, stack) {
      stream.removeListener(listener);
      completer.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

/// Longest side to decode [photo] at for saving: its own, unless that is
/// over [maxSavedPixels] or [maxSavedSide].
int savedSide(MediaItem photo) {
  final longest = math.max(photo.width, photo.height);
  final pixels = photo.width * photo.height;
  final side = pixels > maxSavedPixels
      ? (longest * math.sqrt(maxSavedPixels / pixels)).floor()
      : longest;
  return side.clamp(1, maxSavedSide);
}

/// Full-screen photo editor, above the tabs: crop with handles and fixed
/// shapes, straighten, rotate, flip; enhance, color adjustments and
/// vignette; pencil, blur and pixelate; texts. Previewed live, then saved
/// as a new photo. Dark like the viewer, without ads.
///
/// The preview paints the decoded screen-sized image with [paintEdit];
/// saving paints the full-resolution photo with the same function, so what
/// is seen is what is saved. Holding Before/After shows the original.
/// Closing with changes asks first. Pops with the id of the saved photo.
/// See `docs/features/editor.md`.
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
  StrokeKind _brush = StrokeKind.pen;
  int _penColor = editorColors[2];
  int _widthIndex = 1;
  int? _selectedText;
  bool _showOriginal = false;
  bool _saving = false;

  /// The preview, decoded once.
  EditSource? _source;
  ImageStream? _stream;
  late final _listener = ImageStreamListener((info, _) {
    final previous = _source;
    setState(() => _source = EditSource(info.image));
    previous?.dispose();
  }, onError: (_, _) {});

  MediaItem get photo => widget.photo;

  PhotoEditor get _editor => ref.read(photoEditorProvider(photo).notifier);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = ref
        .read(mediaSourceProvider)
        .preview(photo, longestSide: viewerPreviewSide(context, photo));
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key != _stream?.key) {
      _stream?.removeListener(_listener);
      _stream = stream..addListener(_listener);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _source?.dispose();
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
    final edit = ref.read(photoEditorProvider(photo)).edit;
    if (edit.isIdentity || await _confirmDiscard()) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// Sets brightness and contrast from the histogram of the preview.
  Future<void> _enhance() async {
    final source = _source;
    if (source == null) return;
    final bytes = await source.image.toByteData();
    if (bytes == null || !mounted) return;
    final histogram = luminanceHistogram(bytes.buffer.asUint8List());
    final current = ref.read(photoEditorProvider(photo)).edit.adjustments;
    _editor.setAdjustments(autoEnhance(histogram, base: current));
  }

  /// Asks for the words of a text; `null` when cancelled or empty.
  Future<String?> _askText([String initial = '']) async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => _TextDialog(initial: initial),
    );
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _addText() async {
    final words = await _askText();
    if (words == null || !mounted) return;
    final crop = ref.read(photoEditorProvider(photo)).edit.crop;
    final index = _editor.addText(
      TextItem(
        text: words,
        x: (crop.left + crop.right) / 2,
        y: (crop.top + crop.bottom) / 2,
      ),
    );
    setState(() => _selectedText = index);
  }

  Future<void> _editText(int index) async {
    final text = ref.read(photoEditorProvider(photo)).edit.texts[index];
    final words = await _askText(text.text);
    if (words == null || !mounted) return;
    _editor.updateText(index, text.copyWith(text: words));
  }

  /// Asks how to save, renders the photo at full size and saves it; pops
  /// with the new photo's id.
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
    final edit = ref.read(photoEditorProvider(photo)).edit;
    setState(() => _saving = true);
    EditSource? full;
    try {
      full = EditSource(
        await decodeImage(
          ref
              .read(mediaSourceProvider)
              .fullImage(photo, maxDimension: savedSide(photo)),
        ),
      );
      final rendered = await renderEdit(full, edit);
      final bytes = await rendered.toByteData();
      final width = rendered.width;
      final height = rendered.height;
      rendered.dispose();
      if (bytes == null) throw StateError('no pixels');
      final id = await ref
          .read(platformBridgeProvider)
          .saveEditedPhoto(
            photo,
            width: width,
            height: height,
            rgba: bytes.buffer.asUint8List(),
          );
      await ref.read(mediaIndexProvider.notifier).sync();
      if (mode == SaveMode.replace) {
        await ref.read(mediaActionsProvider).trash([photo]);
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
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.editorSaveFailed)));
    } finally {
      full?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(photoEditorProvider(photo));
    final editor = _editor;
    final edit = state.edit;
    final source = _source;
    final selected = _selectedText;
    final selectedText = selected != null && selected < edit.texts.length
        ? edit.texts[selected]
        : null;

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
              actions: [
                // Held down, shows the original.
                Tooltip(
                  message: l10n.editorBeforeAfter,
                  child: Listener(
                    onPointerDown: (_) => setState(() => _showOriginal = true),
                    onPointerUp: (_) => setState(() => _showOriginal = false),
                    onPointerCancel: (_) =>
                        setState(() => _showOriginal = false),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.compare_rounded,
                        color: edit.isIdentity ? Colors.white38 : null,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.editorReset,
                  onPressed: edit.isIdentity || _saving
                      ? null
                      : () {
                          editor.reset();
                          setState(() => _selectedText = null);
                        },
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
                        child: source == null
                            ? const Center(child: CircularProgressIndicator())
                            : LayoutBuilder(
                                builder: (context, box) {
                                  if (_showOriginal) {
                                    return _ResultView(
                                      source: source,
                                      edit: const PhotoEdit(),
                                      area: box.biggest,
                                    );
                                  }
                                  return switch (_tool) {
                                    EditorTool.crop => _CropView(
                                      source: source,
                                      edit: edit,
                                      area: box.biggest,
                                      onDrag: editor.dragCrop,
                                    ),
                                    EditorTool.filter ||
                                    EditorTool.adjust => _ResultView(
                                      source: source,
                                      edit: edit,
                                      area: box.biggest,
                                    ),
                                    EditorTool.draw => _ResultView(
                                      source: source,
                                      edit: edit,
                                      area: box.biggest,
                                      label: l10n.editorDrawArea,
                                      onPanStart: (point) => editor.startStroke(
                                        point,
                                        kind: _brush,
                                        color: _penColor,
                                        width: _brush == StrokeKind.pen
                                            ? penWidths[_widthIndex]
                                            : areaWidths[_widthIndex],
                                      ),
                                      onPanUpdate: (point, _) =>
                                          editor.extendStroke(point),
                                    ),
                                    EditorTool.text => _TextView(
                                      source: source,
                                      edit: edit,
                                      area: box.biggest,
                                      selected: _selectedText,
                                      onSelect: (index) =>
                                          setState(() => _selectedText = index),
                                      onMove: editor.moveText,
                                      onEdit: _editText,
                                    ),
                                  };
                                },
                              ),
                      ),
                    ),
                    switch (_tool) {
                      EditorTool.crop => CropTools(
                        ratio: state.ratio,
                        angle: edit.angle,
                        onRatio: editor.setRatio,
                        onAngle: editor.straighten,
                        onRotate: editor.rotate,
                        onFlip: editor.flip,
                      ),
                      EditorTool.filter => FilterTools(
                        filter: edit.filter,
                        strength: edit.filterStrength,
                        thumbnail: (filter, side) => _Thumbnail(
                          source: source,
                          // Only the photo and its colors: lines and texts
                          // would not show at this size.
                          edit: edit.copyWith(
                            filter: filter,
                            filterStrength: 1,
                            strokes: const [],
                            texts: const [],
                          ),
                          side: side,
                        ),
                        onFilter: editor.setFilter,
                        onStrength: editor.setFilterStrength,
                      ),
                      EditorTool.adjust => AdjustTools(
                        adjustments: edit.adjustments,
                        selected: _adjustment,
                        onSelected: (a) => setState(() => _adjustment = a),
                        onChanged: (value) => editor.adjust(_adjustment, value),
                        onEnhance: () => unawaited(_enhance()),
                      ),
                      EditorTool.draw => DrawTools(
                        kind: _brush,
                        color: _penColor,
                        widthIndex: _widthIndex,
                        canUndo: edit.strokes.isNotEmpty,
                        onKind: (k) => setState(() => _brush = k),
                        onColor: (c) => setState(() => _penColor = c),
                        onWidth: (w) => setState(() => _widthIndex = w),
                        onUndo: editor.undoStroke,
                      ),
                      EditorTool.text => TextTools(
                        selected: selectedText,
                        onAdd: () => unawaited(_addText()),
                        onEdit: () => unawaited(_editText(selected!)),
                        onChange: (text) => editor.updateText(selected!, text),
                        onDelete: () {
                          editor.removeText(selected!);
                          setState(() => _selectedText = null);
                        },
                      ),
                    },
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                      child: SegmentedButton<EditorTool>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: [
                          ButtonSegment(
                            value: EditorTool.crop,
                            icon: const Icon(Icons.crop_rotate_rounded),
                            tooltip: l10n.editorCrop,
                          ),
                          ButtonSegment(
                            value: EditorTool.filter,
                            icon: const Icon(Icons.filter_vintage_rounded),
                            tooltip: l10n.editorFilters,
                          ),
                          ButtonSegment(
                            value: EditorTool.adjust,
                            icon: const Icon(Icons.tune_rounded),
                            tooltip: l10n.editorAdjust,
                          ),
                          ButtonSegment(
                            value: EditorTool.draw,
                            icon: const Icon(Icons.brush_rounded),
                            tooltip: l10n.editorDraw,
                          ),
                          ButtonSegment(
                            value: EditorTool.text,
                            icon: const Icon(Icons.text_fields_rounded),
                            tooltip: l10n.editorText,
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

/// Paints the edit, and the crop frame on top while cropping.
class _EditPainter extends CustomPainter {
  _EditPainter({
    required this.source,
    required this.edit,
    required this.view,
    this.frame,
    this.selectedText,
  });

  final EditSource source;
  final PhotoEdit edit;
  final CropRect view;

  /// The crop frame's accent color, or `null` for no frame.
  final Color? frame;
  final int? selectedText;

  @override
  void paint(Canvas canvas, Size size) {
    paintEdit(
      canvas,
      size,
      source,
      edit,
      view: view,
      selectedText: selectedText,
    );
    if (frame case final accent?) _paintFrame(canvas, size, edit.crop, accent);
  }

  @override
  bool shouldRepaint(_EditPainter old) =>
      old.source != source ||
      old.edit != edit ||
      old.view != view ||
      old.frame != frame ||
      old.selectedText != selectedText;
}

/// The crop frame: the outside dimmed, thirds lines, accent corners.
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
    required this.source,
    required this.edit,
    required this.area,
    required this.onDrag,
  });

  final EditSource source;
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
    final size = _fit(widget.source.orientedRatio(widget.edit), widget.area);
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
              source: widget.source,
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

/// The result: only the cropped part, as large as it fits. With
/// [onPanStart] and [onPanUpdate], a finger works on it (drawing); points
/// are given in fractions of the whole rotated photo.
class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.source,
    required this.edit,
    required this.area,
    this.label,
    this.onPanStart,
    this.onPanUpdate,
    this.selectedText,
  });

  final EditSource source;
  final PhotoEdit edit;
  final Size area;
  final String? label;
  final ValueChanged<(double, double)>? onPanStart;
  final void Function((double, double) point, Offset delta)? onPanUpdate;
  final int? selectedText;

  /// Size of the view in [area].
  Size get size {
    final crop = edit.crop;
    return _fit(source.orientedRatio(edit) * crop.width / crop.height, area);
  }

  /// A point of the view in fractions of the whole rotated photo.
  (double, double) toPhoto(Offset local) {
    final crop = edit.crop;
    final shown = size;
    return (
      crop.left + local.dx / shown.width * crop.width,
      crop.top + local.dy / shown.height * crop.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final onPanStart = this.onPanStart;
    final onPanUpdate = this.onPanUpdate;
    final painted = CustomPaint(
      size: size,
      painter: _EditPainter(
        source: source,
        edit: edit,
        view: edit.crop,
        selectedText: selectedText,
      ),
    );
    return Center(
      child: onPanStart == null || onPanUpdate == null
          ? painted
          : Semantics(
              label: label,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => onPanStart(toPhoto(d.localPosition)),
                onPanUpdate: (d) =>
                    onPanUpdate(toPhoto(d.localPosition), d.delta),
                child: painted,
              ),
            ),
    );
  }
}

/// The cropped result in a square of [side], or an empty square while the
/// preview decodes.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.source,
    required this.edit,
    required this.side,
  });

  final EditSource? source;
  final PhotoEdit edit;
  final double side;

  @override
  Widget build(BuildContext context) {
    final source = this.source;
    if (source == null) return SizedBox.square(dimension: side);
    final crop = edit.crop;
    return SizedBox.square(
      dimension: side,
      child: Center(
        child: CustomPaint(
          size: _fit(
            source.orientedRatio(edit) * crop.width / crop.height,
            Size.square(side),
          ),
          painter: _EditPainter(source: source, edit: edit, view: crop),
        ),
      ),
    );
  }
}

/// The result with its texts: tap one to select it (or nothing to
/// deselect), drag the selected one to move it, double-tap it to change
/// its words.
class _TextView extends StatelessWidget {
  const _TextView({
    required this.source,
    required this.edit,
    required this.area,
    required this.selected,
    required this.onSelect,
    required this.onMove,
    required this.onEdit,
  });

  final EditSource source;
  final PhotoEdit edit;
  final Size area;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final void Function(int index, double dx, double dy) onMove;
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context) {
    final result = _ResultView(
      source: source,
      edit: edit,
      area: area,
      selectedText: selected,
    );
    final shown = result.size;
    final crop = edit.crop;
    final full = Size(shown.width / crop.width, shown.height / crop.height);

    /// The text under [local], the last drawn first.
    int? textAt(Offset local) {
      final point =
          local + Offset(crop.left * full.width, crop.top * full.height);
      for (var i = edit.texts.length - 1; i >= 0; i--) {
        if (textBounds(edit.texts[i], full).contains(point)) return i;
      }
      return null;
    }

    return Center(
      child: Semantics(
        label: AppLocalizations.of(context).editorTextArea,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => onSelect(textAt(d.localPosition)),
          onDoubleTapDown: (d) {
            if (textAt(d.localPosition) case final i?) onEdit(i);
          },
          onPanStart: (d) {
            if (textAt(d.localPosition) case final i?) onSelect(i);
          },
          onPanUpdate: (d) {
            if (selected case final i?) {
              onMove(i, d.delta.dx / full.width, d.delta.dy / full.height);
            }
          },
          child: SizedBox.fromSize(size: shown, child: result),
        ),
      ),
    );
  }
}

/// Asks for the words of a text. Owns its controller, which the dialog's
/// closing animation still uses after it returns.
class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.initial});

  final String initial;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        widget.initial.isEmpty ? l10n.editorAddText : l10n.editorEditText,
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: 4,
        decoration: InputDecoration(hintText: l10n.editorTextHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.editorCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.editorTextOk),
        ),
      ],
    );
  }
}
