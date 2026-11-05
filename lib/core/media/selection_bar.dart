import 'package:clean_gallery/core/brand/glass.dart';
import 'package:clean_gallery/core/router/compact_nav_bar.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selection_bar.g.dart';

/// Whether a screen of the tabs is selecting items. The shell hides its
/// navigation bar meanwhile, and the screen shows a [SelectionBar] instead.
@Riverpod(keepAlive: true)
class SelectionMode extends _$SelectionMode {
  @override
  bool build() => false;

  /// Enters or leaves selection mode.
  ///
  /// Ignored once the provider is gone: screens release selection mode just
  /// after they are disposed, which can be after the whole app.
  void set({required bool active}) {
    if (!ref.mounted) return;
    if (state != active) state = active;
  }
}

/// One button of a [SelectionBar].
class SelectionAction {
  /// Creates an action. [label] is the tooltip and screen reader label.
  const SelectionAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  /// Icon of the button.
  final IconData icon;

  /// Name of the action.
  final String label;

  /// Runs the action.
  final VoidCallback onPressed;
}

/// Floating pill replacing the navigation bar while items are selected:
/// a close button, the selection count and the actions.
///
/// At most [maxButtons] buttons fit next to the count on a phone: with more
/// actions, the first ones are buttons and the others go in a *More* menu.
///
/// Same place, height and look as [CompactNavBar], so entering selection
/// mode does not move anything.
class SelectionBar extends StatelessWidget {
  /// Creates the bar for [count] selected items.
  const SelectionBar({
    required this.count,
    required this.actions,
    required this.onClose,
    super.key,
  });

  /// Number of selected items.
  final int count;

  /// Buttons, in display order.
  final List<SelectionAction> actions;

  /// Leaves selection mode.
  final VoidCallback onClose;

  /// Number of buttons after the count, *More* included.
  static const maxButtons = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const height = CompactNavBar.height;
    final overflow = actions.length > maxButtons;
    final buttons = overflow ? actions.sublist(0, maxButtons - 1) : actions;
    final menu = overflow
        ? actions.sublist(maxButtons - 1)
        : const <SelectionAction>[];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          12,
          0,
          12,
          CompactNavBar.bottomMargin,
        ),
        child: GlassPill(
          height: height,
          child: Row(
            children: [
              IconButton(
                tooltip: l10n.selectionClose,
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
              Expanded(
                child: Text(
                  l10n.selectionCount(count),
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (final action in buttons)
                IconButton(
                  tooltip: action.label,
                  onPressed: count == 0 ? null : action.onPressed,
                  icon: Icon(action.icon),
                ),
              if (menu.isNotEmpty)
                PopupMenuButton<SelectionAction>(
                  tooltip: l10n.selectionMore,
                  enabled: count > 0,
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (action) => action.onPressed(),
                  itemBuilder: (context) => [
                    for (final action in menu)
                      PopupMenuItem(
                        value: action,
                        child: Row(
                          children: [
                            Icon(action.icon),
                            const SizedBox(width: 12),
                            Expanded(child: Text(action.label)),
                          ],
                        ),
                      ),
                  ],
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
