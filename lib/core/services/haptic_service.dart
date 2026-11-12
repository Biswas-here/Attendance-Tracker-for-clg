import 'package:flutter/services.dart';

class HapticService {
  static bool enabled = true;

  /// Subtle click for navigation, date arrows, minor taps
  static void light() {
    if (enabled) {
      HapticFeedback.lightImpact();
    }
  }

  /// Medium tactile tap for marking attendance, buttons
  static void medium() {
    if (enabled) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Strong tactile impact for decisive actions (Present/Absent confirmation)
  static void heavy() {
    if (enabled) {
      HapticFeedback.heavyImpact();
    }
  }

  /// Selection click for tab change, date picking (triggers vibration motor reliably)
  static void selection() {
    if (enabled) {
      HapticFeedback.selectionClick();
      HapticFeedback.lightImpact();
    }
  }
}

