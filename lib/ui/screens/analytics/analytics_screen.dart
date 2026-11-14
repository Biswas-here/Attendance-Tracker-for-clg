import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/class_session.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/paper_card.dart';
import '../../widgets/staggered_entrance.dart';

class AnalyticsScreen extends StatefulWidget {
  final bool isTabActive;
  const AnalyticsScreen({super.key, this.isTabActive = true});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _chartAnimController;
  late final Animation<double> _chartCurvedAnim;

  @override
  void initState() {
    super.initState();
    _chartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _chartCurvedAnim = CurvedAnimation(
      parent: _chartAnimController,
      curve: Curves.easeOutCubic,
    );
    if (widget.isTabActive) {
      _chartAnimController.forward(from: 0.0);
    } else {
      _chartAnimController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant AnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive && !oldWidget.isTabActive) {
      _chartAnimController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _chartAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final overall = attendance.overallStats;
    final subjects = attendance.subjects;
    final allSessions = attendance.allSessions;
    final target = settings.defaultAttendanceTarget;

    final hasData = overall.totalMarked > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Trends', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100, top: 8),
        children: [
          // ── 3D METRIC SUMMARY TILES ──────────────────────────────────────
          StaggeredEntrance(
            index: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _build3DMetricTile(
                      label: 'ATTENDED',
                      count: '${overall.totalPresent}',
                      subtext: 'Classes',
                      color: AppColors.present,
                      icon: Icons.check_circle_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _build3DMetricTile(
                      label: 'MISSED',
                      count: '${overall.totalAbsent}',
                      subtext: 'Classes',
                      color: AppColors.absent,
                      icon: Icons.cancel_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _build3DMetricTile(
                      label: 'UNMARKED',
                      count: '${overall.totalUnmarked}',
                      subtext: 'Pending',
                      color: AppColors.unmarked,
                      icon: Icons.help_outline_rounded,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!hasData) ...[
            StaggeredEntrance(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: PaperCard(
                  child: Column(
                    children: [
                      const Icon(Icons.analytics_outlined, size: 50, color: AppColors.kraftBrown),
                      const SizedBox(height: 12),
                      const Text(
                        'Insufficient Data for Charts',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mark attendance for at least one class to view 3D graphs, comparisons and trends.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            // ── 1. 3D SUBJECT-WISE BEVELED BAR CHART ────────────────────────
            StaggeredEntrance(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: PaperCard(
                  showTape: true,
                  tapeColor: AppColors.kraftGold,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bar_chart_rounded, size: 22, color: AppColors.craftTeal),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Subject Attendance Comparison',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.kraftGold.withAlpha(isDark ? 40 : 25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.kraftGold.withAlpha(120)),
                            ),
                            child: Text(
                              'Target: ${target.toInt()}%',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.kraftBrown,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '3D grooved pillars. Red cylinders indicate below target.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 225,
                        child: RepaintBoundary(
                          child: _buildSubjectBarChart(
                            subjects: subjects,
                            attendance: attendance,
                            target: target,
                            isDark: isDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 2. 3D LAYERED DONUT PIE CHART ──────────────────────────────
            StaggeredEntrance(
              index: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: PaperCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.pie_chart_outline_rounded, size: 22, color: AppColors.craftPlum),
                          SizedBox(width: 8),
                          Text(
                            'Attendance Distribution',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 180,
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _chartCurvedAnim,
                            builder: (context, _) {
                              final animFactor = _chartCurvedAnim.value;
                              final currentOverallPct = overall.percentage != null
                                  ? (overall.percentage! * animFactor)
                                  : null;
                              final presentPct = overall.totalMarked > 0
                                  ? (((overall.totalPresent / overall.totalMarked) * 100) * animFactor)
                                  : 0.0;
                              final absentPct = overall.totalMarked > 0
                                  ? (((overall.totalAbsent / overall.totalMarked) * 100) * animFactor)
                                  : 0.0;
                              final animatedRadiusPresent = 38.0 * animFactor.clamp(0.05, 1.0);
                              final animatedRadiusAbsent = 34.0 * animFactor.clamp(0.05, 1.0);

                              return Row(
                                children: [
                                  Expanded(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        PieChart(
                                          PieChartData(
                                            sectionsSpace: 4,
                                            centerSpaceRadius: 42,
                                            sections: [
                                              PieChartSectionData(
                                                value: overall.totalPresent.toDouble(),
                                                title: '${overall.totalPresent}',
                                                color: AppColors.present,
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Color.lerp(AppColors.present, Colors.white, 0.25)!,
                                                    AppColors.present,
                                                    Color.lerp(AppColors.present, Colors.black, 0.3)!,
                                                  ],
                                                ),
                                                radius: animatedRadiusPresent,
                                                titleStyle: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
                                                  shadows: [
                                                    Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1)),
                                                  ],
                                                ),
                                              ),
                                              PieChartSectionData(
                                                value: overall.totalAbsent.toDouble(),
                                                title: '${overall.totalAbsent}',
                                                color: AppColors.absent,
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Color.lerp(AppColors.absent, Colors.white, 0.25)!,
                                                    AppColors.absent,
                                                    Color.lerp(AppColors.absent, Colors.black, 0.3)!,
                                                  ],
                                                ),
                                                radius: animatedRadiusAbsent,
                                                titleStyle: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 13,
                                                  shadows: [
                                                    Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Central 3D Embossed Medallion
                                        Container(
                                          width: 72,
                                          height: 72,
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF262320) : const Color(0xFFFBF8F2),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong,
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withAlpha(isDark ? 90 : 35),
                                                offset: const Offset(0, 3),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                currentOverallPct != null
                                                    ? '${currentOverallPct.toStringAsFixed(0)}%'
                                                    : '--',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.craftTeal,
                                                ),
                                              ),
                                              Text(
                                                'OVERALL',
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.6,
                                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _build3DPieLegend(
                                        color: AppColors.present,
                                        label: 'Present',
                                        count: '${overall.totalPresent}',
                                        sub: '${presentPct.toStringAsFixed(1)}%',
                                        isDark: isDark,
                                      ),
                                      const SizedBox(height: 12),
                                      _build3DPieLegend(
                                        color: AppColors.absent,
                                        label: 'Absent',
                                        count: '${overall.totalAbsent}',
                                        sub: '${absentPct.toStringAsFixed(1)}%',
                                        isDark: isDark,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 3. 3D ATTENDANCE TREND RIBBON (LINE CHART) ──────────────────
            StaggeredEntrance(
              index: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: PaperCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.show_chart_rounded, size: 22, color: AppColors.craftTeal),
                          SizedBox(width: 8),
                          Text(
                            'Attendance Rate Trend',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tactile progression timeline with craft pin markers',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 195,
                        child: RepaintBoundary(
                          child: _buildAttendanceTrendChart(
                            allSessions: allSessions,
                            target: target,
                            isDark: isDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 3D METRIC TILE WIDGET ────────────────────────────────────────────────
  Widget _build3DMetricTile({
    required String label,
    required String count,
    required String subtext,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262320) : const Color(0xFFF9F5EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 85 : 30),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
          BoxShadow(
            color: color.withAlpha(isDark ? 30 : 15),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            count,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: color,
              shadows: [
                Shadow(
                  color: Colors.black.withAlpha(isDark ? 80 : 25),
                  offset: const Offset(0, 1.5),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── 3D SUBJECT-WISE BEVELED BAR CHART ────────────────────────────────────
  Widget _buildSubjectBarChart({
    required List<dynamic> subjects,
    required AttendanceProvider attendance,
    required double target,
    required bool isDark,
  }) {
    if (subjects.isEmpty) {
      return const Center(child: Text('No subjects added'));
    }

    final data = <_BarSubjectData>[];
    for (final s in subjects) {
      final stats = attendance.getSubjectStats(s.id);
      final pct = stats.percentage ?? 0.0;
      final meetsTarget = pct >= target;
      final baseColor = meetsTarget ? AppColors.present : AppColors.absent;

      // Intelligent horizontal label formatting:
      // If code is short (<= 5 chars), use it.
      // If name has multiple words (e.g. "DBMS LAB"), split across 2 lines.
      // Otherwise keep full name and FittedBox will scale it horizontally.
      String labelText;
      final code = s.code as String?;
      if (code != null && code.trim().isNotEmpty && code.trim().length <= 5) {
        labelText = code.trim().toUpperCase();
      } else {
        final name = (s.name as String).trim();
        if (name.contains(' ')) {
          final words = name.split(RegExp(r'\s+'));
          if (words.length >= 2) {
            labelText = '${words[0]}\n${words.sublist(1).join(" ")}';
          } else {
            labelText = name;
          }
        } else {
          labelText = name;
        }
      }

      data.add(_BarSubjectData(
        label: labelText,
        pct: pct,
        color: baseColor,
        fullName: s.name as String,
        attended: stats.presentCount,
        total: stats.totalMarked,
      ));
    }

    const double chartHeight = 145.0;
    final yAxisColor = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final gridLineColor = isDark ? const Color(0xFF332F2A) : const Color(0xFFE4DFD3);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── LEFT Y-AXIS ──────────────────────────────────────────────
            SizedBox(
              width: 32,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 18),
                  Text('100%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: yAxisColor)),
                  Text('75%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.kraftGold)),
                  Text('50%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: yAxisColor)),
                  Text('25%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: yAxisColor)),
                  Text('0%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: yAxisColor)),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ── CHART AREA WITH GRID & SEPARATED 3D PILLARS ──────────────
            Expanded(
              child: Stack(
                children: [
                  // Horizontal Grid Lines
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 26, bottom: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(height: 1, color: gridLineColor),
                          Container(height: 1.5, color: AppColors.kraftGold.withAlpha(160)),
                          Container(height: 1, color: gridLineColor),
                          Container(height: 1, color: gridLineColor),
                          Container(height: 1.2, color: gridLineColor),
                        ],
                      ),
                    ),
                  ),

                  // Horizontally scrollable row of distinct, disconnected 3D pillars
                  Positioned.fill(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: AnimatedBuilder(
                        animation: _chartCurvedAnim,
                        builder: (context, _) {
                          final animFactor = _chartCurvedAnim.value;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: data.map((d) {
                              final currentPct = d.pct * animFactor;
                              final double fillFraction = (currentPct / 100.0).clamp(0.0, 1.0);
                              final double filledHeight = (fillFraction * chartHeight).clamp(0.0, chartHeight);
                              final bool isTallEnough = filledHeight >= 36.0;

                              return Tooltip(
                                message: '${d.fullName}\n${d.pct.toStringAsFixed(1)}% (${d.attended}/${d.total} attended)',
                                child: InkWell(
                                  onTap: () => HapticService.selection(),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 64,
                                    margin: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Percentage Badge above pillar
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: d.color.withAlpha(isDark ? 40 : 25),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: d.color.withAlpha(120), width: 1),
                                          ),
                                          child: Text(
                                            '${currentPct.toInt()}%',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: d.color,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),

                                        // 3D Pillar Container
                                        Container(
                                          width: 56,
                                          height: chartHeight,
                                          decoration: BoxDecoration(
                                            color: (isDark ? const Color(0xFF221F1C) : const Color(0xFFEDE7DA)).withAlpha(180),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                              width: 1.2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withAlpha(isDark ? 50 : 20),
                                                offset: const Offset(0, 2),
                                                blurRadius: 3,
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            alignment: Alignment.bottomCenter,
                                            children: [
                                              // Raised 3D Pillar fill
                                              Container(
                                                width: 56,
                                                height: filledHeight,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(7),
                                                  gradient: LinearGradient(
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                    colors: [
                                                      Color.lerp(d.color, Colors.white, 0.38)!,
                                                      d.color,
                                                      Color.lerp(d.color, Colors.black, 0.35)!,
                                                    ],
                                                    stops: const [0.0, 0.45, 1.0],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: d.color.withAlpha(80),
                                                      offset: const Offset(0, -1),
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Subject Label: inside pillar, horizontally formatted!
                                              Positioned(
                                                bottom: isTallEnough ? (filledHeight / 2) - 14 : 6,
                                                left: 2,
                                                right: 2,
                                                child: IgnorePointer(
                                                  child: SizedBox(
                                                    width: 52,
                                                    height: 28,
                                                    child: Center(
                                                      child: FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        alignment: Alignment.center,
                                                        child: Text(
                                                          d.label,
                                                          textAlign: TextAlign.center,
                                                          maxLines: 2,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w900,
                                                            height: 1.05,
                                                            letterSpacing: 0.3,
                                                            color: isTallEnough
                                                                ? Colors.white
                                                                : (isDark ? Colors.white70 : Colors.black87),
                                                            shadows: isTallEnough
                                                                ? const [
                                                                    Shadow(
                                                                      color: Colors.black87,
                                                                      blurRadius: 3,
                                                                      offset: Offset(0, 1),
                                                                    ),
                                                                  ]
                                                                : null,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
} // end AnalyticsScreen


// ────────────────────────────────────────────────────────────────────────────
// Helper data class for bar chart
// ────────────────────────────────────────────────────────────────────────────
class _BarSubjectData {
  final String label;
  final double pct;
  final Color color;
  final String fullName;
  final int attended;
  final int total;

  const _BarSubjectData({
    required this.label,
    required this.pct,
    required this.color,
    required this.fullName,
    required this.attended,
    required this.total,
  });
}

// ── 3D PIE LEGEND PILL ───────────────────────────────────────────────────
Widget _build3DPieLegend({
    required Color color,
    required String label,
    required String count,
    required String sub,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262320) : const Color(0xFFF9F5EC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 60 : 20),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(80),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label: $count',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3D ATTENDANCE TREND CHART ────────────────────────────────────────────
  Widget _buildAttendanceTrendChart({
    required List<ClassSession> allSessions,
    required double target,
    required bool isDark,
  }) {
    final markedSessions = allSessions
        .where((s) => s.status != AttendanceStatus.unmarked)
        .toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

    if (markedSessions.isEmpty) {
      return const Center(child: Text('No marked sessions for trendline'));
    }

    final spots = <FlSpot>[];
    int cumulativePresent = 0;
    int cumulativeTotal = 0;

    for (int i = 0; i < markedSessions.length; i++) {
      final s = markedSessions[i];
      cumulativeTotal++;
      if (s.status == AttendanceStatus.present) {
        cumulativePresent++;
      }
      final pct = (cumulativePresent / cumulativeTotal) * 100.0;
      spots.add(FlSpot(i.toDouble(), pct));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (val) {
            if (val == target) {
              return FlLine(color: AppColors.kraftGold, strokeWidth: 1.8, dashArray: [5, 4]);
            }
            return FlLine(
              color: isDark ? const Color(0xFF33302B) : const Color(0xFFE2DDD2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 25,
              getTitlesWidget: (val, meta) => Text(
                '${val.toInt()}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (val, meta) {
                final i = val.toInt();
                if (i == 0 || i == spots.length - 1 || (spots.length > 4 && i == spots.length ~/ 2)) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '#${i + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: AppColors.craftTeal,
            barWidth: 3.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: spots.length <= 25,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 3.5,
                color: Colors.white,
                strokeWidth: 2.5,
                strokeColor: AppColors.craftTeal,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.craftTeal.withAlpha(isDark ? 80 : 50),
                  AppColors.craftTeal.withAlpha(0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

