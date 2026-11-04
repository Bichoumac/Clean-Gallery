import 'package:clean_gallery/core/brand/petal_mark.dart';
import 'package:flutter/material.dart';

/// An empty state: the mark, a title, secondary text and an optional button,
/// all centered. Errors do not use it: an error is not a brand moment.
class EmptyState extends StatelessWidget {
  /// Creates the state.
  const EmptyState({
    required this.title,
    this.body,
    this.action,
    this.bodyWidget,
    this.padding = const EdgeInsets.fromLTRB(32, 56, 32, 0),
    super.key,
  });

  /// What is empty.
  final String title;

  /// Secondary text.
  final String? body;

  /// Shown instead of [body], for text that changes by itself.
  final Widget? bodyWidget;

  /// Optional button.
  final Widget? action;

  /// Space around the state.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const EmptyMark(),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          if (bodyWidget case final widget?) ...[
            const SizedBox(height: 12),
            DefaultTextStyle.merge(
              style: style,
              textAlign: TextAlign.center,
              child: widget,
            ),
          ] else if (body case final text?) ...[
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: style),
          ],
          if (action case final button?) ...[
            const SizedBox(height: 24),
            button,
          ],
        ],
      ),
    );
  }
}
