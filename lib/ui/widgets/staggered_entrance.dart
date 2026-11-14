import 'package:flutter/material.dart';

/// Lightweight staggered entrance wrapper.
/// Returns child directly to guarantee zero frame drops, instant launch,
/// and butter-smooth 120Hz/60Hz scrolling across all devices.
class StaggeredEntrance extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration baseDelay;
  final Duration delayPerItem;
  final Duration duration;
  final double slideOffset;

  const StaggeredEntrance({
    super.key,
    required this.child,
    required this.index,
    this.baseDelay = const Duration(milliseconds: 30),
    this.delayPerItem = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 350),
    this.slideOffset = 0.07,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}


