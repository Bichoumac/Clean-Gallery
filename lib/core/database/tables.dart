import 'package:clean_gallery/domain/enums.dart';
import 'package:drift/drift.dart';

/// Media items indexed from the device, keyed by their MediaStore id.
///
/// The media index: every list of the app reads it, and `MediaIndex` keeps it
/// in sync with MediaStore. Analysis columns are nullable because they are
/// filled incrementally by the analysis engine. `analysisVersion` records
/// which algorithm produced them.
@DataClassName('AssetRow')
@TableIndex(name: 'assets_taken_at', columns: {#takenAt})
@TableIndex(name: 'assets_bucket_id', columns: {#bucketId})
class Assets extends Table {
  /// MediaStore id of the item.
  IntColumn get id => integer()();

  /// Folder (album) name as reported by MediaStore.
  TextColumn get folder => text()();

  /// Folder id (MediaStore `BUCKET_ID`); `null` until the item is indexed.
  TextColumn get bucketId => text().nullable()();

  /// Path relative to the storage root, e.g. `DCIM/Camera/`.
  TextColumn get relativePath => text()();

  /// File name with extension.
  TextColumn get fileName => text()();

  /// MIME type, e.g. `image/jpeg`.
  TextColumn get mimeType => text()();

  /// Whether this item is a photo or a video.
  TextColumn get kind => textEnum<MediaKind>()();

  /// File size in bytes.
  IntColumn get sizeBytes => integer()();

  /// Width in pixels.
  IntColumn get width => integer()();

  /// Height in pixels.
  IntColumn get height => integer()();

  /// Duration in milliseconds, videos only.
  IntColumn get durationMs => integer().nullable()();

  /// Last modification date of the file.
  DateTimeColumn get modifiedAt => dateTime()();

  /// Capture date as reported by MediaStore: `DATE_TAKEN`, or `DATE_ADDED`
  /// when unset. Timelines are sorted and grouped by it.
  DateTimeColumn get takenAt => dateTime()();

  /// MediaStore `GENERATION_MODIFIED` when the row was last indexed. It
  /// changes whenever the item changes; `null` forces a refresh.
  IntColumn get mediaRevision => integer().nullable()();

  /// Capture date resolved by the analysis engine (EXIF, file name).
  DateTimeColumn get captureAt => dateTime().nullable()();

  /// Where [captureAt] was read from.
  TextColumn get captureSource => textEnum<DateSource>().nullable()();

  /// xxHash of the file content, used for exact duplicates.
  TextColumn get contentHash => text().nullable()();

  /// 64-bit difference hash (dHash), stored as a signed integer.
  Int64Column get dHash => int64().nullable()();

  /// 64-bit perceptual hash (pHash), stored as a signed integer.
  Int64Column get pHash => int64().nullable()();

  /// Sharpness score (variance of the Laplacian). Higher is sharper.
  RealColumn get blurScore => real().nullable()();

  /// Burst identifier, shared by all photos of one burst sequence.
  TextColumn get burstId => text().nullable()();

  /// Whether the item is a screenshot.
  BoolColumn get isScreenshot => boolean().withDefault(const Constant(false))();

  /// Whether the item is marked as a favorite in MediaStore.
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  /// Latitude from EXIF GPS data.
  RealColumn get latitude => real().nullable()();

  /// Longitude from EXIF GPS data.
  RealColumn get longitude => real().nullable()();

  /// Camera model from EXIF data.
  TextColumn get cameraModel => text().nullable()();

  /// Version of the analysis algorithms that produced the analysis columns.
  IntColumn get analysisVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A group of assets considered duplicates of each other.
@DataClassName('DuplicateGroupRow')
class DuplicateGroups extends Table {
  /// Auto-incremented identifier.
  IntColumn get id => integer().autoIncrement()();

  /// Category of the group.
  TextColumn get kind => textEnum<DuplicateKind>()();

  /// When the group was computed.
  DateTimeColumn get computedAt => dateTime()();
}

/// Membership of an asset in a duplicate group.
@DataClassName('DuplicateMemberRow')
class DuplicateMembers extends Table {
  /// Group this membership belongs to.
  IntColumn get groupId =>
      integer().references(DuplicateGroups, #id, onDelete: KeyAction.cascade)();

  /// Asset that is a member of the group.
  IntColumn get assetId =>
      integer().references(Assets, #id, onDelete: KeyAction.cascade)();

  /// Whether this asset is the one suggested to keep (the "Best" badge).
  BoolColumn get isSuggestedKeep =>
      boolean().withDefault(const Constant(false))();

  /// Confidence score of the match, from 0 to 1.
  RealColumn get score => real().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {groupId, assetId};
}

/// Pairs of assets the user marked as "not duplicates".
///
/// Always stored with `assetA < assetB` so each pair appears once.
@DataClassName('IgnoredPairRow')
class IgnoredPairs extends Table {
  /// Smaller asset id of the pair.
  @ReferenceName('ignoredAsFirst')
  IntColumn get assetA =>
      integer().references(Assets, #id, onDelete: KeyAction.cascade)();

  /// Larger asset id of the pair.
  @ReferenceName('ignoredAsSecond')
  IntColumn get assetB =>
      integer().references(Assets, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {assetA, assetB};
}

/// Assets moved to the app trash. The file stays on disk until purged.
@DataClassName('TrashRow')
class TrashEntries extends Table {
  /// Asset in the trash.
  IntColumn get assetId =>
      integer().references(Assets, #id, onDelete: KeyAction.cascade)();

  /// When the asset was moved to the trash.
  DateTimeColumn get trashedAt => dateTime()();

  /// When the asset becomes eligible for permanent deletion.
  DateTimeColumn get expiresAt => dateTime()();

  /// Folder the asset came from, used when restoring it.
  TextColumn get originalFolder => text()();

  @override
  Set<Column<Object>> get primaryKey => {assetId};
}

/// Actions taken during swipe sessions, so sessions can be resumed.
@DataClassName('SwipeHistoryRow')
class SwipeHistory extends Table {
  /// Auto-incremented identifier.
  IntColumn get id => integer().autoIncrement()();

  /// Identifier of the swipe session.
  TextColumn get session => text()();

  /// Position of the card within the session.
  IntColumn get order => integer()();

  /// Asset that was swiped.
  IntColumn get assetId =>
      integer().references(Assets, #id, onDelete: KeyAction.cascade)();

  /// Action taken on the card.
  TextColumn get action => textEnum<SwipeAction>()();
}

/// Application key/value settings, including cached purchase state.
@DataClassName('SettingRow')
class Settings extends Table {
  /// Setting name, e.g. `trash_retention_days`.
  TextColumn get key => text()();

  /// Setting value, stored as text.
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
