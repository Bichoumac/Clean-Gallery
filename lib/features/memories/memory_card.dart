import 'dart:async';

import 'package:clean_gallery/core/media/media_providers.dart';
import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/domain/memory.dart';
import 'package:clean_gallery/features/memories/memory_providers.dart';
import 'package:clean_gallery/features/memories/reminder_planner.dart';
import 'package:clean_gallery/features/slideshow/slideshow_actions.dart';
import 'package:clean_gallery/features/slideshow/slideshow_builder.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Today's memories at the top of the Camera tab, one card each, side by
/// side when there are several; nothing when there are none.
class MemoryCards extends ConsumerWidget {
  /// Creates the row of cards.
  const MemoryCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(memoryCardsProvider);
    if (memories.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: memories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) =>
              SizedBox(width: 216, child: MemoryCard(memory: memories[index])),
        ),
      ),
    );
  }
}

/// One memory: a cover photo with its title and count; a tap plays it, ✕
/// dismisses it (Undo).
class MemoryCard extends ConsumerWidget {
  /// Creates the card of [memory].
  const MemoryCard({required this.memory, super.key});

  /// The memory shown.
  final Memory memory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cover = ref
        .watch(albumCoverProvider(memory.selection.copyWith(goodOnly: true)))
        .value;
    final title = memoryTitle(l10n, memory);
    final subtitle = [
      memoryDateLabel(context, memory),
      l10n.photoCount(memory.count),
    ].join(' · ');
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: theme.colorScheme.surfaceContainerHigh,
          child: InkWell(
            onTap: () =>
                unawaited(playSlideshow(context, MemorySlideshow(memory))),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cover != null) MediaThumbnail(item: cover, hero: false),
                // Keeps the white text readable on any photo.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xB3000000)],
                      stops: [0.35, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    tooltip: l10n.memoryDismiss,
                    color: Colors.white,
                    iconSize: 18,
                    onPressed: () =>
                        unawaited(dismissMemory(context, ref, memory)),
                    icon: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0x8C000000),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
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

/// Dismisses [memory] from the card and the list, offering Undo.
Future<void> dismissMemory(
  BuildContext context,
  WidgetRef ref,
  Memory memory,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repository = ref.read(memoryRepositoryProvider);
  await repository.setDismissed(memory.key, dismissed: true);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // With an action, it would stay until closed.
        persist: false,
        content: Text(l10n.memoryDismissedSnack),
        action: SnackBarAction(
          label: l10n.actionUndo,
          onPressed: () =>
              unawaited(repository.setDismissed(memory.key, dismissed: false)),
        ),
      ),
    );
}

/// The day or week of [memory], e.g. "4 Nov 2025" or "3 – 9 Nov 2025".
String memoryDateLabel(BuildContext context, Memory memory) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final start = memory.dates.start!;
  final last = memory.dates.end!.subtract(const Duration(days: 1));
  final full = DateFormat.yMMMd(locale);
  if (memory.kind == MemoryKind.onThisDay) return full.format(start);
  final first = start.month == last.month
      ? DateFormat.d(locale).format(start)
      : DateFormat.MMMd(locale).format(start);
  return '$first – ${full.format(last)}';
}
