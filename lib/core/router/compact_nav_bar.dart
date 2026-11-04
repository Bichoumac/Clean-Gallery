import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// One destination of [CompactNavBar].
class CompactNavDestination {
  /// Creates a destination. [label] is not displayed: it is used for the
  /// tooltip and the screen reader.
  const CompactNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  /// Icon shown when the destination is not selected.
  final IconData icon;

  /// Icon shown when the destination is selected.
  final IconData selectedIcon;

  /// Name of the destination, for tooltips and accessibility.
  final String label;
}

/// Small floating navigation bar with icons only.
///
/// A pill floating above the content, with a translucent blurred background.
/// The selected icon sits on an accent pill. Labels are not shown but every
/// icon has a tooltip and a screen reader label, and a 48 dp touch target.
class CompactNavBar extends StatelessWidget {
  /// Creates the bar.
  const CompactNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  /// Height of the pill, excluding the bottom margin.
  static const height = 56.0;

  /// Space between the pill and the bottom of the screen (above the system
  /// navigation area).
  static const bottomMargin = 12.0;

  /// Destinations, in display order.
  final List<CompactNavDestination> destinations;

  /// Index of the selected destination.
  final int selectedIndex;

  /// Called with the index of the tapped destination.
  final ValueChanged<int> onSelected;

  /// Bottom padding that scrollable content needs so it is not hidden under
  /// the bar.
  static double contentInset(BuildContext context) =>
      height + bottomMargin * 2 + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: bottomMargin),
        child: Center(
          heightFactor: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainer.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(height / 2),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: SizedBox(
                  height: height,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < destinations.length; i++)
                          _NavItem(
                            destination: destinations[i],
                            selected: i == selectedIndex,
                            onTap: () => onSelected(i),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final CompactNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      excludeSemantics: true,
      child: Tooltip(
        message: destination.label,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: SizedBox(
            width: 56,
            height: 48,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 48 : 40,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 22,
                  color: selected
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
