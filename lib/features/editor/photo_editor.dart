import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/photo_edit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'photo_editor.freezed.dart';
part 'photo_editor.g.dart';

/// What the editor shows: the edit so far and the crop shape picked.
@freezed
abstract class PhotoEditorState with _$PhotoEditorState {
  /// Creates the state.
  const factory PhotoEditorState({
    @Default(PhotoEdit()) PhotoEdit edit,
    @Default(CropRatio.free) CropRatio ratio,
  }) = _PhotoEditorState;
}

/// Edits one photo: rotation, flip, crop and color adjustments, as a
/// [PhotoEdit]. Nothing touches the photo until it is saved.
@riverpod
class PhotoEditor extends _$PhotoEditor {
  @override
  PhotoEditorState build(MediaItem photo) => const PhotoEditorState();

  /// Width divided by height of the photo as shown (rotated).
  double get _photoRatio => state.edit.orientedRatio(photo.width, photo.height);

  /// Turns the photo a quarter clockwise. A fixed crop shape turns too
  /// (4:3 becomes 3:4), except a square.
  void rotate() {
    final edit = state.edit.rotated();
    final ratio = switch (state.ratio) {
      CropRatio.fourThree => CropRatio.threeFour,
      CropRatio.threeFour => CropRatio.fourThree,
      CropRatio.sixteenNine => CropRatio.nineSixteen,
      CropRatio.nineSixteen => CropRatio.sixteenNine,
      final other => other,
    };
    state = state.copyWith(edit: edit, ratio: ratio);
  }

  /// Mirrors the photo left to right.
  void flip() => state = state.copyWith(edit: state.edit.mirrored());

  /// Picks the crop shape; the crop becomes the largest of that shape
  /// around its center.
  void setRatio(CropRatio ratio) {
    final pixelRatio = ratio.pixelRatio(_photoRatio);
    final crop = pixelRatio == null
        ? state.edit.crop
        : fitRatio(state.edit.crop, pixelRatio, _photoRatio);
    state = state.copyWith(
      ratio: ratio,
      edit: state.edit.copyWith(crop: crop),
    );
  }

  /// Moves the crop, or one of its corners, by [dx], [dy] (fractions of
  /// the photo), keeping its shape.
  void dragCrop(CropHandle handle, double dx, double dy) {
    final crop = state.edit.crop;
    final moved = handle == CropHandle.inside
        ? crop.moved(dx, dy)
        : dragCorner(
            crop,
            handle,
            dx,
            dy,
            pixelRatio: state.ratio.pixelRatio(_photoRatio),
            photoRatio: _photoRatio,
          );
    state = state.copyWith(edit: state.edit.copyWith(crop: moved));
  }

  /// Sets [adjustment] to [value] (-1 to 1).
  void adjust(Adjustment adjustment, double value) {
    final edit = state.edit;
    state = state.copyWith(
      edit: edit.copyWith(
        adjustments: adjustment.set(edit.adjustments, value.clamp(-1, 1)),
      ),
    );
  }

  /// Straightens the photo by [degrees] (-45 to 45).
  void straighten(double degrees) => state = state.copyWith(
    edit: state.edit.copyWith(angle: degrees.clamp(-45, 45)),
  );

  /// Replaces every color adjustment, e.g. with "Enhance".
  void setAdjustments(Adjustments adjustments) => state = state.copyWith(
    edit: state.edit.copyWith(adjustments: adjustments),
  );

  /// Starts a line of [kind] at [point] (fractions of the rotated photo).
  void startStroke(
    (double, double) point, {
    required int color,
    required double width,
    StrokeKind kind = StrokeKind.pen,
  }) {
    final edit = state.edit;
    state = state.copyWith(
      edit: edit.copyWith(
        strokes: [
          ...edit.strokes,
          Stroke(kind: kind, points: [point], color: color, width: width),
        ],
      ),
    );
  }

  /// Continues the last line to [point].
  void extendStroke((double, double) point) {
    final strokes = state.edit.strokes;
    if (strokes.isEmpty) return;
    final last = strokes.last;
    state = state.copyWith(
      edit: state.edit.copyWith(
        strokes: [
          ...strokes.sublist(0, strokes.length - 1),
          last.copyWith(points: [...last.points, point]),
        ],
      ),
    );
  }

  /// Removes the last line.
  void undoStroke() {
    final strokes = state.edit.strokes;
    if (strokes.isEmpty) return;
    state = state.copyWith(
      edit: state.edit.copyWith(
        strokes: strokes.sublist(0, strokes.length - 1),
      ),
    );
  }

  /// Adds [text]; returns its index.
  int addText(TextItem text) {
    final texts = [...state.edit.texts, text];
    state = state.copyWith(edit: state.edit.copyWith(texts: texts));
    return texts.length - 1;
  }

  /// Replaces text [index] with [text].
  void updateText(int index, TextItem text) {
    final texts = [...state.edit.texts];
    if (index < 0 || index >= texts.length) return;
    texts[index] = text;
    state = state.copyWith(edit: state.edit.copyWith(texts: texts));
  }

  /// Moves text [index] by [dx], [dy] (fractions), keeping its center on
  /// the photo.
  void moveText(int index, double dx, double dy) {
    final texts = state.edit.texts;
    if (index < 0 || index >= texts.length) return;
    final text = texts[index];
    updateText(
      index,
      text.copyWith(x: (text.x + dx).clamp(0, 1), y: (text.y + dy).clamp(0, 1)),
    );
  }

  /// Removes text [index].
  void removeText(int index) {
    final texts = [...state.edit.texts];
    if (index < 0 || index >= texts.length) return;
    texts.removeAt(index);
    state = state.copyWith(edit: state.edit.copyWith(texts: texts));
  }

  /// Back to the photo as it was.
  void reset() => state = const PhotoEditorState();
}
