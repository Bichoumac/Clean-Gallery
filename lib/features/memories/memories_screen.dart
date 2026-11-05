import 'package:clean_gallery/core/brand/petal_mark.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/router/compact_nav_bar.dart';
import 'package:clean_gallery/domain/memory.dart';
import 'package:clean_gallery/features/memories/memory_card.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// *Memories* (Albums tab): every memory met so far and not dismissed, the
/// most recently found first. A tap plays one, ✕ dismisses it.
class MemoriesScreen extends ConsumerWidget {
  /// Creates the list.
  const MemoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final memories = ref.watch(storedMemoriesProvider).value;
    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(4, 24, 14, 16),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const BackButton(),
                  Expanded(
                    child: Text(
                      l10n.memoriesTitle,
                      style: theme.textTheme.headlineLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        switch (memories) {
          null => const SliverToBoxAdapter(child: SizedBox.shrink()),
          [] => SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EmptyMark(),
                    const SizedBox(height: 16),
                    Text(
                      l10n.memoriesEmpty,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          final List<Memory> list => SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            sliver: SliverList.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => SizedBox(
                height: 168,
                child: MemoryCard(
                  key: ValueKey(list[index].key),
                  memory: list[index],
                ),
              ),
            ),
          ),
        },
        SliverToBoxAdapter(
          child: SizedBox(height: CompactNavBar.contentInset(context)),
        ),
      ],
    );
  }
}
