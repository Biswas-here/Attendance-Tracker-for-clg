import 'package:flutter/material.dart';
import '../../core/models/class_session.dart';
import '../../core/models/subject.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/nerdy_icons.dart';
import 'paper_button.dart';
import 'paper_card.dart';
import 'paper_stamp.dart';

class ActiveClassModalBanner extends StatefulWidget {
  final List<ClassSession> activeSessions;
  final Map<String, Subject> subjectsMap;
  final Future<void> Function(String sessionId, AttendanceStatus status) onMarkAttendance;

  const ActiveClassModalBanner({
    super.key,
    required this.activeSessions,
    required this.subjectsMap,
    required this.onMarkAttendance,
  });

  @override
  State<ActiveClassModalBanner> createState() => _ActiveClassModalBannerState();
}

class _ActiveClassModalBannerState extends State<ActiveClassModalBanner>
    with TickerProviderStateMixin {
  late String _selectedSessionId;
  bool _showSuccessAnimation = false;
  AttendanceStatus? _justMarkedStatus;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _selectedSessionId = widget.activeSessions.first.id;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ActiveClassModalBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.activeSessions.any((s) => s.id == _selectedSessionId)) {
      _selectedSessionId = widget.activeSessions.first.id;
    }
  }

  ClassSession get _currentSession {
    return widget.activeSessions.firstWhere(
      (s) => s.id == _selectedSessionId,
      orElse: () => widget.activeSessions.first,
    );
  }

  Future<void> _handleMark(AttendanceStatus status) async {
    setState(() {
      _showSuccessAnimation = true;
      _justMarkedStatus = status;
    });

    await widget.onMarkAttendance(_currentSession.id, status);

    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() {
        _showSuccessAnimation = false;
        _justMarkedStatus = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _currentSession;
    final subject = widget.subjectsMap[session.subjectId];
    final isAlreadyMarked = session.status != AttendanceStatus.unmarked;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PaperCard(
      showTape: true,
      tapeColor: AppColors.craftOrange,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderColor: AppColors.craftOrange.withAlpha(160),
      color: isDark ? const Color(0xFF2C251D) : const Color(0xFFFFF9F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row — live indicator
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (ctx, _) => Opacity(
                  opacity: _pulseAnim.value,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.craftOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'CLASS IN SESSION NOW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                  color: AppColors.craftOrange,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.craftOrange.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.craftOrange.withAlpha(100)),
                ),
                child: Text(
                  AppDateUtils.formatTimeRange(session.startTime, session.endTime),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.craftOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Multi-class selector
          if (widget.activeSessions.length > 1) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white60,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: widget.activeSessions.map((s) {
                  final isSelected = s.id == _selectedSessionId;
                  final sSub = widget.subjectsMap[s.subjectId];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSessionId = s.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.craftTeal : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sSub?.name ?? 'Subject',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Subject name + teacher with Nerdy Badge
          Row(
            children: [
              NerdySubjectBadge(
                subjectName: subject?.name ?? 'Class',
                subjectId: subject?.id,
                colorValue: subject?.colorValue ?? 0xFFE65100,
                size: 42,
                iconSize: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject?.name ?? 'Scheduled Class',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (subject?.teacher != null && subject!.teacher!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            subject.teacher!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- Body: success animation / already marked / mark buttons ---
          if (_showSuccessAnimation) ...[
            _buildSuccessFeedback(),
          ] else if (isAlreadyMarked) ...[
            _buildAlreadyMarkedState(session, isDark),
          ] else ...[
            _buildMarkButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildSuccessFeedback() {
    final isPresent = _justMarkedStatus == AttendanceStatus.present;
    final color = isPresent ? AppColors.present : AppColors.absent;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.elasticOut,
      builder: (ctx, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: color,
              size: 56,
            ),
            const SizedBox(height: 10),
            Text(
              isPresent ? 'MARKED PRESENT ✓' : 'MARKED ABSENT',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlreadyMarkedState(ClassSession session, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF22201D) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance marked for this session',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                PaperStampBadge(status: session.status),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              final newStatus = session.status == AttendanceStatus.present
                  ? AttendanceStatus.absent
                  : AttendanceStatus.present;
              _handleMark(newStatus);
            },
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: Text(
              session.status == AttendanceStatus.present ? 'Mark Absent' : 'Mark Present',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkButtons() {
    return Row(
      children: [
        Expanded(
          child: AttendanceActionButton(
            title: 'PRESENT',
            color: AppColors.present,
            icon: Icons.check_circle_rounded,
            onTap: () => _handleMark(AttendanceStatus.present),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: AttendanceActionButton(
            title: 'ABSENT',
            color: AppColors.absent,
            icon: Icons.cancel_rounded,
            onTap: () => _handleMark(AttendanceStatus.absent),
          ),
        ),
      ],
    );
  }
}
