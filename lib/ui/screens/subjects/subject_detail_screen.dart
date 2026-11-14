import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/nerdy_icons.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/paper_card.dart';
import '../../widgets/paper_progress_bar.dart';
import '../../widgets/paper_stamp.dart';
import 'add_edit_subject_dialog.dart';

class SubjectDetailScreen extends StatelessWidget {
  final String subjectId;

  const SubjectDetailScreen({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final subject = attendance.getSubjectById(subjectId);

    if (subject == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subject')),
        body: const Center(child: Text('Subject not found')),
      );
    }

    final stats = attendance.getSubjectStats(subjectId);
    final target = subject.targetPercentage ?? settings.defaultAttendanceTarget;
    final meetsTarget = stats.meetsTarget(target);

    final allSubjectSessions = attendance.getSessionsForSubject(subjectId).toList()
      ..sort((a, b) => b.startDateTime.compareTo(a.startDateTime)); // newest first

    final now = DateTime.now();
    final upcomingSessions = allSubjectSessions.where((s) => s.startDateTime.isAfter(now)).toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

    final pastSessions = allSubjectSessions.where((s) => !s.startDateTime.isAfter(now)).toList();

    final classesNeeded = stats.classesNeededForTarget(target);
    final classesCanMiss = stats.classesCanMiss(target);

    return Scaffold(
      appBar: AppBar(
        title: Text(subject.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Edit Subject',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AddEditSubjectDialog(subjectToEdit: subject),
              );
            },
          ),
          IconButton(
            tooltip: 'Delete Subject',
            icon: const Icon(Icons.delete_outline, color: AppColors.absent),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Subject?'),
                  content: Text(
                    'Are you sure you want to delete "${subject.name}"?\n\nThis will permanently delete all associated class schedules and attendance records.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.absent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete Subject'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await attendance.deleteSubject(subjectId);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 60),
        children: [
          // Header Card with Percentage & Progress
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: PaperCard(
              showTape: true,
              tapeColor: Color(subject.colorValue),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NerdySubjectBadge(
                        subjectName: subject.name,
                        subjectId: subject.id,
                        colorValue: subject.colorValue,
                        size: 48,
                        iconSize: 26,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (subject.code != null) ...[
                              Text(
                                subject.code!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(subject.colorValue),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              subject.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                            ),
                            if (subject.teacher != null && subject.teacher!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Instructor: ${subject.teacher}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            stats.percentage != null
                                ? '${stats.percentage!.toStringAsFixed(1)}%'
                                : '--',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: stats.percentage == null
                                  ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                                  : (meetsTarget ? AppColors.present : AppColors.absent),
                            ),
                          ),
                          Text(
                            'Target: ${target.toInt()}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  PaperLinearProgress(
                    percentage: stats.percentage,
                    targetPercentage: target,
                    height: 14,
                  ),
                  const SizedBox(height: 16),

                  // Counts Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem('Present', '${stats.presentCount}', AppColors.present),
                      _buildMetricItem('Absent', '${stats.absentCount}', AppColors.absent),
                      _buildMetricItem('Total Marked', '${stats.totalMarked}', isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      _buildMetricItem('Unmarked', '${stats.unmarkedCount}', AppColors.unmarked),
                    ],
                  ),

                  // Target guidance advice
                  if (stats.percentage != null) ...[
                    const Divider(height: 24),
                    if (meetsTarget)
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppColors.present, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              classesCanMiss > 0
                                  ? 'On track! You can miss up to $classesCanMiss class${classesCanMiss == 1 ? "" : "es"} without falling below $target%.'
                                  : 'On track! Do not miss the next class to maintain your target.',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.absent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Below target! You must attend $classesNeeded consecutive class${classesNeeded == 1 ? "" : "es"} to reach $target%.',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.absent,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),

          // Upcoming Classes Section
          if (upcomingSessions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'UPCOMING CLASSES (${upcomingSessions.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
            ...upcomingSessions.take(3).map((session) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: PaperCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.event_outlined, size: 18, color: AppColors.craftTeal),
                      const SizedBox(width: 10),
                      Text(
                        AppDateUtils.formatShortDate(session.startDateTime),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        AppDateUtils.formatTimeRange(session.startTime, session.endTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          // Attendance History Section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Text(
                  'ATTENDANCE HISTORY (${pastSessions.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  'Tap P / A to edit',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),

          if (pastSessions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No past sessions recorded for this subject.',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            )
          else
            ...pastSessions.map((session) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: PaperCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppDateUtils.formatDisplayDate(session.startDateTime),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            Text(
                              AppDateUtils.formatTimeRange(session.startTime, session.endTime),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      QuickAttendanceStamps(
                        currentStatus: session.status,
                        onStatusChanged: (newStatus) {
                          attendance.markAttendance(session.id, newStatus);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
