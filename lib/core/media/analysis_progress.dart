import 'package:clean_gallery/core/media/duplicates.dart';
import 'package:clean_gallery/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fraction of the running duplicate scan done, between 0 and 1, or `null`
/// when no scan runs or it has nothing to read.
double? analysisFraction(DuplicateScanState scan) {
  if (!scan.running || scan.toHash == 0) return null;
  return (scan.hashed / scan.toHash).clamp(0.0, 1.0);
}

/// "Analyzing: 1,200 of 8,000 items" while the duplicate scan reads the
/// library; nothing otherwise.
class AnalysisProgressText extends ConsumerWidget {
  /// Creates the label, drawn with [style].
  const AnalysisProgressText({this.style, this.textAlign, super.key});

  /// Text style of the label.
  final TextStyle? style;

  /// Alignment of the label.
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(duplicateScanProvider);
    if (analysisFraction(scan) == null) return const SizedBox.shrink();
    final done = scan.hashed.clamp(0, scan.toHash);
    return Text(
      AppLocalizations.of(context).analysisProgress(done, scan.toHash),
      style: style,
      textAlign: textAlign,
    );
  }
}
