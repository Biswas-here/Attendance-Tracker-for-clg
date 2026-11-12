import 'package:flutter/material.dart';

class NerdyIcons {
  static const List<IconData> icons = [
    Icons.terminal_rounded,
    Icons.science_rounded,
    Icons.biotech_rounded,
    Icons.psychology_rounded,
    Icons.calculate_rounded,
    Icons.memory_rounded,
    Icons.code_rounded,
    Icons.developer_board_rounded,
    Icons.precision_manufacturing_rounded,
    Icons.rocket_launch_rounded,
    Icons.pest_control_rounded,
    Icons.videogame_asset_rounded,
    Icons.smart_toy_rounded,
    Icons.data_object_rounded,
    Icons.functions_rounded,
    Icons.hub_rounded,
    Icons.dns_rounded,
    Icons.architecture_rounded,
    Icons.electrical_services_rounded,
    Icons.lightbulb_outline_rounded,
    Icons.analytics_rounded,
    Icons.auto_stories_rounded,
    Icons.school_rounded,
    Icons.devices_other_rounded,
    Icons.integration_instructions_rounded,
  ];

  /// Deterministically returns a nerdy icon for a given subject identifier
  static IconData getIcon(String key) {
    if (key.isEmpty) return Icons.code_rounded;
    int hash = 0;
    for (int i = 0; i < key.length; i++) {
      hash = (hash * 31 + key.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return icons[hash % icons.length];
  }
}

/// A paper-stamped nerdy badge widget for subjects
class NerdySubjectBadge extends StatelessWidget {
  final String subjectName;
  final String? subjectId;
  final int colorValue;
  final double size;
  final double iconSize;

  const NerdySubjectBadge({
    super.key,
    required this.subjectName,
    this.subjectId,
    required this.colorValue,
    this.size = 36.0,
    this.iconSize = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    final icon = NerdyIcons.getIcon(subjectId ?? subjectName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withAlpha(140),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            offset: const Offset(0, 2),
            blurRadius: 3,
          ),
        ],
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: color,
      ),
    );
  }
}

