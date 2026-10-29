import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clean_gallery/analysis/color_matrix.dart';
import 'package:clean_gallery/analysis/document.dart';
import 'package:clean_gallery/analysis/enhance.dart';
import 'package:clean_gallery/core/media/media_index.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/theme/app_theme.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/features/editor/editor_screen.dart';
import 'package:clean_gallery/features/viewer/zoomable_image.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Turns a photo of a document into a flat, readable page: finds the
/// sheet's four corners ([detectDocument], adjustable by hand), flattens
/// the perspective, and renders it in color, gray, or black and white;
/// saved as a new photo next to the original. Pops with its id.
///
/// See `docs/features/scan.md`.
class ScanScreen extends ConsumerStatefulWidget {
  /// Creates the scanner of [photo].
  const ScanScreen({required this.photo, super.key});

  /// The photo of a document.
  final MediaItem photo;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  ui.Image? _image;
  ImageStream? _stream;
  late final _listener = ImageStreamListener((info, _) {
    _image?.dispose();
    _image = info.image;
    unawaited(_detect(info.image));
  }, onError: (_, _) {});

  /// Corners of the page, top left first, clockwise, in fractions.
  List<Point>? _corners;
  bool _found = false;

  /// Whether the flattened page is shown (second step).
  bool _flat = false;
  DocumentMode _mode = DocumentMode.color;

  /// Luminance of the flattened page, for the rendering modes.
  List<int>? _histogram;
  bool _saving = false;

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
    _image?.dispose();
    super.dispose();
  }

  Future<void> _detect(ui.Image image) async {
    final bytes = await image.toByteData();
    if (!mounted) return;
    final corners = bytes == null
        ? null
        : detectDocument(
            grayFromRgba(bytes.buffer.asUint8List(), image.width, image.height),
          );
    setState(() {
      _corners = corners ?? defaultCorners;
      _found = corners != null;
    });
  }

  /// Flattens the preview once to measure its light, then shows it.
  Future<void> _next() async {
    final image = _image;
    final corners = _corners;
    if (image == null || corners == null) return;
    final page = await renderPage(image, corners, maxSide: 600);
    final bytes = await page.toByteData();
    page.dispose();
    if (!mounted) return;
    setState(() {
      _histogram = bytes == null
          ? null
          : luminanceHistogram(bytes.buffer.asUint8List(), step: 1);
      _flat = true;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final corners = _corners!;
    final matrix = _matrix;
    setState(() => _saving = true);
    ui.Image? full;
    try {
      full = await decodeImage(
        ref
            .read(mediaSourceProvider)
            .fullImage(widget.photo, maxDimension: savedSide(widget.photo)),
      );
      final page = await renderPage(full, corners, matrix: matrix);
      final bytes = await page.toByteData();
      final width = page.width;
      final height = page.height;
      page.dispose();
      if (bytes == null) throw StateError('no pixels');
      final id = await ref
          .read(platformBridgeProvider)
          .saveEditedPhoto(
            widget.photo,
            width: width,
            height: height,
            rgba: bytes.buffer.asUint8List(),
          );
      await ref.read(mediaIndexProvider.notifier).sync();
      messenger.showSnackBar(SnackBar(content: Text(l10n.scanSaved)));
      navigator.pop(id);
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.editorSaveFailed)));
    } finally {
      full?.dispose();
    }
  }

  ColorMatrix? get _matrix {
    final histogram = _histogram;
    return histogram == null ? null : documentMatrix(_mode, histogram);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final image = _image;
    final corners = _corners;
    return Theme(
      data: AppTheme.dark(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: PopScope(
          // Back from the flat page returns to the corners.
          canPop: !_flat && !_saving,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !_saving) setState(() => _flat = false);
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: Text(l10n.scanTitle),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _flat
                      ? FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.editorSave),
                        )
                      : FilledButton(
                          onPressed: corners == null ? null : _next,
                          child: Text(l10n.scanNext),
                        ),
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
                      child: image == null || corners == null
                          ? const Center(child: CircularProgressIndicator())
                          : LayoutBuilder(
                              builder: (context, box) => _flat
                                  ? _PageView(
                                      image: image,
                                      corners: corners,
                                      matrix: _matrix,
                                      area: box.biggest,
                                    )
                                  : _CornersView(
                                      image: image,
                                      corners: corners,
                                      area: box.biggest,
                                      onMove: (index, point) => setState(
                                        () =>
                                            _corners = [...corners]
                                              ..[index] = point,
                                      ),
                                    ),
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _flat
                        ? SegmentedButton<DocumentMode>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(
                                value: DocumentMode.color,
                                label: Text(l10n.scanModeColor),
                              ),
                              ButtonSegment(
                                value: DocumentMode.gray,
                                label: Text(l10n.scanModeGray),
                              ),
                              ButtonSegment(
                                value: DocumentMode.blackWhite,
                                label: Text(l10n.scanModeBlackWhite),
                              ),
                            ],
                            selected: {_mode},
                            onSelectionChanged: _saving
                                ? null
                                : (modes) =>
                                      setState(() => _mode = modes.single),
                          )
                        : Text(
                            corners == null
                                ? ''
                                : _found
                                ? l10n.scanCornersFound
                                : l10n.scanCornersPlace,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
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

/// Size of a box of [ratio] (width / height) fitted in [area].
Size _fit(double ratio, Size area) => ratio >= area.width / area.height
    ? Size(area.width, area.width / ratio)
    : Size(area.height * ratio, area.height);

/// [corners] (fractions) in pixels of a [width] × [height] image.
List<Point> _inPixels(List<Point> corners, double width, double height) => [
  for (final (x, y) in corners) (x * width, y * height),
];

/// The perspective transform of a canvas drawing an image so that its
/// [corners] (pixels) land on the corners of a [size] page.
Float64List _pageTransform(List<Point> corners, Size size) {
  final h = homography(corners, [
    (0, 0),
    (size.width, 0),
    (size.width, size.height),
    (0, size.height),
  ]);
  // The 3 × 3 transform as a column-major 4 × 4, z left alone.
  return Float64List.fromList([
    h[0], h[3], 0, h[6], //
    h[1], h[4], 0, h[7],
    0, 0, 1, 0,
    h[2], h[5], 0, h[8],
  ]);
}

/// Paints the page of [image] inside [corners] (fractions) flattened into
/// [size], with [matrix] applied.
void paintPage(
  Canvas canvas,
  Size size,
  ui.Image image,
  List<Point> corners, {
  ColorMatrix? matrix,
}) {
  final pixels = _inPixels(
    corners,
    image.width.toDouble(),
    image.height.toDouble(),
  );
  canvas
    ..save()
    ..clipRect(Offset.zero & size)
    ..transform(_pageTransform(pixels, size))
    ..drawImage(
      image,
      Offset.zero,
      Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = matrix == null ? null : ColorFilter.matrix(matrix),
    )
    ..restore();
}

/// The page of [image] inside [corners] flattened at its own resolution
/// (its longer sides), at most [maxSide] pixels and [maxSavedPixels].
Future<ui.Image> renderPage(
  ui.Image image,
  List<Point> corners, {
  ColorMatrix? matrix,
  int maxSide = maxSavedSide,
}) {
  final (w, h) = pageSize(
    _inPixels(corners, image.width.toDouble(), image.height.toDouble()),
  );
  var scale = math.min(1, maxSide / math.max(w, h)).toDouble();
  scale = math.min(scale, math.sqrt(maxSavedPixels / (w * h)));
  final width = math.max(1, (w * scale).round());
  final height = math.max(1, (h * scale).round());
  final recorder = ui.PictureRecorder();
  paintPage(
    Canvas(recorder),
    Size(width.toDouble(), height.toDouble()),
    image,
    corners,
    matrix: matrix,
  );
  final picture = recorder.endRecording();
  return picture.toImage(width, height).whenComplete(picture.dispose);
}

/// The photo with the page outlined; a corner follows the finger that
/// drags it.
class _CornersView extends StatefulWidget {
  const _CornersView({
    required this.image,
    required this.corners,
    required this.area,
    required this.onMove,
  });

  final ui.Image image;
  final List<Point> corners;
  final Size area;
  final void Function(int index, Point point) onMove;

  @override
  State<_CornersView> createState() => _CornersViewState();
}

/// Distance from a corner within which a touch grabs it.
const _reach = 48.0;

class _CornersViewState extends State<_CornersView> {
  int? _dragged;

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final size = _fit(image.width / image.height, widget.area);
    int? cornerAt(Offset point) {
      int? best;
      var bestDistance = _reach;
      for (final (i, (x, y)) in widget.corners.indexed) {
        final d = (Offset(x * size.width, y * size.height) - point).distance;
        if (d < bestDistance) {
          bestDistance = d;
          best = i;
        }
      }
      return best;
    }

    return Center(
      child: Semantics(
        label: AppLocalizations.of(context).scanCornersArea,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _dragged = cornerAt(d.localPosition),
          onPanUpdate: (d) {
            final index = _dragged;
            if (index == null) return;
            final p = d.localPosition;
            widget.onMove(index, (
              (p.dx / size.width).clamp(0.0, 1.0),
              (p.dy / size.height).clamp(0.0, 1.0),
            ));
          },
          onPanEnd: (_) => _dragged = null,
          child: CustomPaint(
            size: size,
            painter: _CornersPainter(
              image: image,
              corners: widget.corners,
              accent: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  _CornersPainter({
    required this.image,
    required this.corners,
    required this.accent,
  });

  final ui.Image image;
  final List<Point> corners;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final page = Path()
      ..addPolygon([
        for (final (x, y) in corners) Offset(x * size.width, y * size.height),
      ], true);
    canvas
      ..drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(Offset.zero & size),
          page,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.55),
      )
      ..drawPath(
        page,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    for (final (x, y) in corners) {
      final center = Offset(x * size.width, y * size.height);
      canvas
        ..drawCircle(
          center,
          14,
          Paint()..color = accent.withValues(alpha: 0.35),
        )
        ..drawCircle(center, 7, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(_CornersPainter old) =>
      old.image != image || old.corners != corners || old.accent != accent;
}

/// The flattened page as large as it fits.
class _PageView extends StatelessWidget {
  const _PageView({
    required this.image,
    required this.corners,
    required this.matrix,
    required this.area,
  });

  final ui.Image image;
  final List<Point> corners;
  final ColorMatrix? matrix;
  final Size area;

  @override
  Widget build(BuildContext context) {
    final (w, h) = pageSize(
      _inPixels(corners, image.width.toDouble(), image.height.toDouble()),
    );
    return Center(
      child: CustomPaint(
        size: _fit(w / h, area),
        painter: _PagePainter(image: image, corners: corners, matrix: matrix),
      ),
    );
  }
}

class _PagePainter extends CustomPainter {
  _PagePainter({required this.image, required this.corners, this.matrix});

  final ui.Image image;
  final List<Point> corners;
  final ColorMatrix? matrix;

  @override
  void paint(Canvas canvas, Size size) =>
      paintPage(canvas, size, image, corners, matrix: matrix);

  @override
  bool shouldRepaint(_PagePainter old) =>
      old.image != image || old.corners != corners || old.matrix != matrix;
}
