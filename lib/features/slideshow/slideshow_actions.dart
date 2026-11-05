import 'dart:async';

import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/router/app_router.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/domain/album.dart';
import 'package:clean_gallery/domain/media_item.dart';
import 'package:clean_gallery/domain/slideshow.dart';
import 'package:clean_gallery/features/library/sort_filter_sheet.dart';
import 'package:clean_gallery/features/slideshow/slideshow_builder.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Opens the player on [source] with [options], or the user's defaults.
Future<void> playSlideshow(
  BuildContext context,
  SlideshowSource source, {
  SlideshowOptions? options,
}) => context.push(
  AppRoutes.slideshow,
  extra: SlideshowArgs(source: source, options: options),
);

/// Shows the options sheet for [source], remembers the options chosen, and
/// plays it; does nothing when the sheet is closed.
Future<void> startSlideshow(
  BuildContext context,
  WidgetRef ref,
  SlideshowSource source,
) async {
  final chosen = await showSlideshowOptions(context, ref);
  if (chosen == null || !context.mounted) return;
  await playSlideshow(context, source, options: chosen.options);
}

/// Asks for an album and a period with the options, then plays the photos
/// and videos of that album in that period (Albums → *Slideshow*).
Future<void> startPeriodSlideshow(BuildContext context, WidgetRef ref) async {
  final now = DateTime.now();
  final chosen = await showSlideshowOptions(
    context,
    ref,
    period: datePresetRange(DatePreset.last30Days, now),
  );
  if (chosen == null || !context.mounted) return;
  final l10n = AppLocalizations.of(context);
  final dates = chosen.dates;
  final album = chosen.album;
  final period = dates == null
      ? l10n.filterAllTime
      : dateFilterLabel(context, dates, now);
  // "Holidays · Last 30 days", or the period alone for the whole library.
  final title = album == null ? period : '${album.name} · $period';
  await playSlideshow(
    context,
    SelectionSlideshow(
      (album?.selection ?? MediaSelection.all).copyWith(dates: dates),
      title: title,
    ),
    options: chosen.options,
  );
}

/// What the options sheet returns: the options, and the period and album
/// when they were asked (`null` album: the whole library).
typedef SlideshowChoice = ({
  SlideshowOptions options,
  DateFilter? dates,
  SlideshowAlbum? album,
});

/// An album a custom slideshow can play: Favorites, a user album or a
/// device folder.
typedef SlideshowAlbum = ({MediaSelection selection, String name});

/// Shows the slideshow options, starting from the user's defaults; with
/// [period], also the period choices, starting from it. *Start* saves the
/// options as the new defaults and returns them; closing returns `null`.
Future<SlideshowChoice?> showSlideshowOptions(
  BuildContext context,
  WidgetRef ref, {
  DateFilter? period,
  bool asDefaults = false,
}) async {
  final settings = ref.read(appSettingsControllerProvider.notifier);
  final before = ref.read(appSettingsControllerProvider).slideshowOptions;
  final chosen = await showModalBottomSheet<SlideshowChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SlideshowOptionsSheet(
      initial: before,
      period: period,
      askPeriod: period != null,
      asDefaults: asDefaults,
    ),
  );
  if (chosen == null) return null;
  await settings.setSlideshowOptions(chosen.options);
  if (before.music case DeviceMusic(:final uri)
      when chosen.options.music != before.music) {
    await releaseUnusedMusic(ref, uri);
  }
  return chosen;
}

/// Gives back the read access to the phone track [uri] when neither the
/// defaults nor a saved slideshow use it any more.
Future<void> releaseUnusedMusic(WidgetRef ref, String uri) async {
  final defaults = ref.read(appSettingsControllerProvider).slideshowOptions;
  if (defaults.music case DeviceMusic(uri: final used) when used == uri) {
    return;
  }
  final saved = await ref.read(slideshowRepositoryProvider).deviceMusicUris();
  if (saved.contains(uri)) return;
  await ref.read(musicPlayerProvider).release(uri);
}

/// Asks for a title, proposing [title], and saves [items] in their order
/// with [options] in *My slideshows*; returns the new id, or `null` when
/// cancelled.
Future<int?> saveSlideshow(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required SlideshowOptions options,
  required List<MediaItem> items,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final name = await askSlideshowTitle(
    context,
    initial: title.isEmpty ? l10n.slideshowDefaultTitle : title,
    heading: l10n.slideshowSaveTitle,
    action: l10n.actionSave,
  );
  if (name == null) return null;
  final id = await ref.read(slideshowRepositoryProvider).save(name, options, [
    for (final item in items) item.id,
  ]);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l10n.slideshowSavedSnack),
        // Above the player's buttons, which it would otherwise cover.
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 180),
      ),
    );
  return id;
}

/// Renames the saved [slideshow].
Future<void> renameSavedSlideshow(
  BuildContext context,
  WidgetRef ref,
  SavedSlideshow slideshow,
) async {
  final l10n = AppLocalizations.of(context);
  final name = await askSlideshowTitle(
    context,
    initial: slideshow.title,
    heading: l10n.slideshowRename,
    action: l10n.actionRename,
  );
  if (name == null || name == slideshow.title) return;
  await ref.read(slideshowRepositoryProvider).rename(slideshow.id, name);
}

/// Deletes the saved [slideshow], offering Undo; the photos stay.
Future<void> deleteSavedSlideshow(
  BuildContext context,
  WidgetRef ref,
  SavedSlideshow slideshow,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repository = ref.read(slideshowRepositoryProvider);
  final deleted = await repository.delete(slideshow.id);
  if (deleted == null) return;
  var undone = false;
  messenger.hideCurrentSnackBar();
  final snack = messenger.showSnackBar(
    SnackBar(
      // With an action, it would stay until closed.
      persist: false,
      content: Text(l10n.slideshowDeletedSnack),
      action: SnackBarAction(
        label: l10n.actionUndo,
        onPressed: () {
          undone = true;
          unawaited(repository.restore(deleted));
        },
      ),
    ),
  );
  // Once Undo is no longer offered, its phone track may be given back.
  if (slideshow.options.music case DeviceMusic(:final uri)) {
    await snack.closed;
    if (!undone) await releaseUnusedMusic(ref, uri);
  }
}

/// Asks for a slideshow title; `null` when cancelled.
Future<String?> askSlideshowTitle(
  BuildContext context, {
  required String initial,
  required String heading,
  required String action,
}) => showDialog<String>(
  context: context,
  builder: (context) =>
      _TitleDialog(initial: initial, heading: heading, action: action),
);

class _TitleDialog extends StatefulWidget {
  const _TitleDialog({
    required this.initial,
    required this.heading,
    required this.action,
  });

  final String initial;
  final String heading;
  final String action;

  @override
  State<_TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<_TitleDialog> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.heading),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l10n.slideshowTitleLabel),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, value, _) => FilledButton(
            onPressed: value.text.trim().isEmpty ? null : _submit,
            child: Text(widget.action),
          ),
        ),
      ],
    );
  }
}

/// The options of a slideshow: time per photo, transition, order, videos,
/// skipping duplicates and blurry photos, music; with [askPeriod], the
/// album and the period first. *Start* (or *Save* for [asDefaults])
/// returns them.
class SlideshowOptionsSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const SlideshowOptionsSheet({
    required this.initial,
    this.period,
    this.askPeriod = false,
    this.asDefaults = false,
    super.key,
  });

  /// Options shown first.
  final SlideshowOptions initial;

  /// Period shown first, when [askPeriod].
  final DateFilter? period;

  /// Whether the period choices are shown.
  final bool askPeriod;

  /// Whether the sheet edits the defaults (Settings) rather than starting
  /// a slideshow.
  final bool asDefaults;

  @override
  ConsumerState<SlideshowOptionsSheet> createState() =>
      _SlideshowOptionsSheetState();
}

class _SlideshowOptionsSheetState extends ConsumerState<SlideshowOptionsSheet> {
  late SlideshowOptions _options = widget.initial;
  late DateFilter? _dates = widget.period;

  /// Album picked, or `null` for every photo and video.
  SlideshowAlbum? _album;
  final _now = DateTime.now();

  /// A phone track picked earlier, still offered after choosing another.
  late DeviceMusic? _deviceTrack = switch (widget.initial.music) {
    final DeviceMusic music => music,
    _ => null,
  };

  void _set(SlideshowOptions options) => setState(() => _options = options);

  Future<void> _pickTrack() async {
    final picked = await ref.read(musicPlayerProvider).pick();
    if (picked == null || !mounted) return;
    setState(() {
      _deviceTrack = picked;
      _options = _options.copyWith(music: picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final deviceTrack = _deviceTrack;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.asDefaults ? l10n.slideshowDefaults : l10n.slideshowTitle,
              style: theme.textTheme.titleLarge,
            ),
            if (widget.askPeriod) ...[
              heading(l10n.slideshowAlbum),
              _AlbumMenu(
                album: _album,
                onChanged: (album) => setState(() => _album = album),
              ),
              heading(l10n.slideshowPeriod),
              DateRangeChips(
                dates: _dates,
                now: _now,
                onChanged: (dates) => setState(() => _dates = dates),
              ),
            ],
            heading(l10n.slideshowPhotoDuration),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final seconds in SlideshowOptions.photoSecondsChoices)
                  ButtonSegment(
                    value: seconds,
                    label: Text(l10n.slideshowSeconds(seconds)),
                  ),
              ],
              selected: {_options.photoSeconds},
              onSelectionChanged: (value) =>
                  _set(_options.copyWith(photoSeconds: value.single)),
            ),
            heading(l10n.slideshowTransition),
            SegmentedButton<SlideshowTransition>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: SlideshowTransition.crossfade,
                  label: Text(l10n.slideshowCrossfade),
                ),
                ButtonSegment(
                  value: SlideshowTransition.kenBurns,
                  label: Text(l10n.slideshowKenBurns),
                ),
              ],
              selected: {_options.transition},
              onSelectionChanged: (value) =>
                  _set(_options.copyWith(transition: value.single)),
            ),
            heading(l10n.slideshowOrder),
            SegmentedButton<SlideshowOrder>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: SlideshowOrder.byDate,
                  label: Text(l10n.slideshowByDate),
                ),
                ButtonSegment(
                  value: SlideshowOrder.shuffled,
                  label: Text(l10n.slideshowShuffled),
                ),
              ],
              selected: {_options.order},
              onSelectionChanged: (value) =>
                  _set(_options.copyWith(order: value.single)),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.slideshowIncludeVideos),
              subtitle: Text(
                l10n.slideshowIncludeVideosHint(
                  SlideshowOptions.maxVideoSeconds,
                ),
              ),
              value: _options.includeVideos,
              onChanged: (value) =>
                  _set(_options.copyWith(includeVideos: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.slideshowSkip),
              subtitle: Text(l10n.slideshowSkipHint),
              value: _options.skipDuplicatesAndBlurry,
              onChanged: (value) =>
                  _set(_options.copyWith(skipDuplicatesAndBlurry: value)),
            ),
            heading(l10n.slideshowMusic),
            RadioGroup<SlideshowMusic>(
              groupValue: _options.music,
              onChanged: (music) {
                if (music != null) _set(_options.copyWith(music: music));
              },
              child: Column(
                children: [
                  RadioListTile<SlideshowMusic>(
                    contentPadding: EdgeInsets.zero,
                    value: const SlideshowMusic.none(),
                    title: Text(l10n.slideshowMusicNone),
                  ),
                  for (final track in bundledTracks)
                    RadioListTile<SlideshowMusic>(
                      contentPadding: EdgeInsets.zero,
                      value: SlideshowMusic.bundled(track.id),
                      title: Text(track.title),
                    ),
                  if (deviceTrack != null)
                    RadioListTile<SlideshowMusic>(
                      contentPadding: EdgeInsets.zero,
                      value: deviceTrack,
                      title: Text(
                        deviceTrack.name.isEmpty
                            ? l10n.slideshowMusicPhone
                            : deviceTrack.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(l10n.slideshowMusicPhone),
                    ),
                ],
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => unawaited(_pickTrack()),
                icon: const Icon(Icons.library_music_outlined),
                label: Text(l10n.slideshowMusicPick),
              ),
            ),
            if (bundledTracks.isEmpty)
              Text(
                l10n.slideshowMusicNoBundled,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, (
                options: _options,
                dates: _dates,
                album: _album,
              )),
              icon: Icon(
                widget.asDefaults
                    ? Icons.check_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                widget.asDefaults ? l10n.actionSave : l10n.slideshowStart,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Choice of the album a custom slideshow plays: every photo and video,
/// Favorites, the user's albums, then the device folders.
class _AlbumMenu extends ConsumerWidget {
  const _AlbumMenu({required this.album, required this.onChanged});

  final SlideshowAlbum? album;
  final ValueChanged<SlideshowAlbum?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mine = ref.watch(userAlbumsProvider).value ?? const <UserAlbum>[];
    final folders = ref.watch(albumsProvider).value ?? const <Album>[];
    final choices = <SlideshowAlbum?>[
      null,
      (selection: MediaSelection.favorites, name: l10n.albumsFavorites),
      for (final a in mine) (selection: a.selection, name: a.name),
      for (final f in folders) (selection: f.selection, name: f.name),
    ];
    return DropdownMenu<SlideshowAlbum?>(
      expandedInsets: EdgeInsets.zero,
      initialSelection: album,
      leadingIcon: const Icon(Icons.photo_album_outlined),
      // Long lists of folders: typing narrows them.
      enableFilter: true,
      requestFocusOnTap: false,
      menuHeight: 360,
      onSelected: onChanged,
      dropdownMenuEntries: [
        for (final choice in choices)
          DropdownMenuEntry(
            value: choice,
            label: choice?.name ?? l10n.albumsAllMedia,
            leadingIcon: Icon(switch (choice) {
              null => Icons.photo_library_outlined,
              (:final selection, name: _) when selection.userAlbumId != null =>
                Icons.collections_bookmark_outlined,
              (:final selection, name: _)
                  when selection.filter == MediaFilter.favorites =>
                Icons.favorite_border_rounded,
              _ => Icons.folder_outlined,
            }),
          ),
      ],
    );
  }
}
