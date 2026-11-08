import 'package:clean_gallery/core/theme/app_motion.dart';
import 'package:flutter/widgets.dart';

/// The tabs' navigators, one shown at a time, sliding like pages of a
/// carousel when the tab changes: the new tab comes in from the side of its
/// button while the old one leaves on the other side.
///
/// As `StatefulShellRoute.indexedStack`, every tab keeps its state. Only the
/// current tab runs its tickers, takes touches and has its heroes on: the
/// Camera tab and an album page can show the same item, and two heroes with
/// one tag in the shell break the flight to the viewer.
class TabSwitcher extends StatefulWidget {
  /// Creates the switcher showing [children] at [index].
  const TabSwitcher({required this.index, required this.children, super.key});

  /// Tab shown.
  final int index;

  /// One navigator per tab, in the order of the navigation bar.
  final List<Widget> children;

  @override
  State<TabSwitcher> createState() => _TabSwitcherState();
}

class _TabSwitcherState extends State<TabSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.tab,
    value: 1,
  )..addStatusListener(_onStatus);

  /// Tab leaving the screen, while the animation runs.
  int? _previous;

  @override
  void didUpdateWidget(TabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == oldWidget.index) return;
    final duration = AppMotion.of(context, AppMotion.tab);
    if (duration == Duration.zero) {
      _previous = null;
      _controller.value = 1;
      return;
    }
    _previous = oldWidget.index;
    _controller
      ..duration = duration
      ..forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status.isCompleted && _previous != null) {
      setState(() => _previous = null);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.index;
    final previous = _previous;
    // 1 when the new tab is to the right of the old one, -1 to the left.
    final direction = previous == null || current > previous ? 1.0 : -1.0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = AppMotion.pageCurve.transform(_controller.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            for (final (index, child) in widget.children.indexed)
              // Same widgets around each tab whatever the state, so no tab
              // loses its state when it starts or stops moving.
              Offstage(
                offstage: index != current && index != previous,
                child: TickerMode(
                  enabled: index == current,
                  child: HeroMode(
                    enabled: index == current,
                    child: IgnorePointer(
                      ignoring: index != current,
                      child: FractionalTranslation(
                        translation: Offset(
                          index == current
                              ? direction * (1 - t)
                              : index == previous
                              ? -direction * t
                              : 0,
                          0,
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
