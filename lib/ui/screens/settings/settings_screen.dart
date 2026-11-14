import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/paper_card.dart';
import 'csv_import_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _institutionController;
  late TextEditingController _courseController;
  late TextEditingController _semesterController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _nameController = TextEditingController(text: settings.studentName);
    _institutionController = TextEditingController(text: settings.institutionName);
    _courseController = TextEditingController(text: settings.courseName);
    _semesterController = TextEditingController(text: settings.semester);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _courseController.dispose();
    _semesterController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    context.read<SettingsProvider>().updateStudentProfile(
          name: _nameController.text.trim(),
          institution: _institutionController.text.trim(),
          course: _courseController.text.trim(),
          semester: _semesterController.text.trim(),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile details saved.')),
    );
  }

  Future<void> _pickProfileImage(SettingsProvider prov) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (result.isNotEmpty && result.first.path != null) {
        await prov.setProfileImage(result.first.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _showProfileImageSheet(BuildContext context, SettingsProvider prov, dynamic settings) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Profile Picture',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.craftTeal),
                title: const Text('Choose from Storage / Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProfileImage(prov);
                },
              ),
              if (settings.profileImagePath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.absent),
                  title: const Text('Remove Profile Picture', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.absent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    prov.setProfileImage(null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProv = context.watch<SettingsProvider>();
    final attendance = context.read<AttendanceProvider>();
    final settings = settingsProv.settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
        children: [
          // ── PROFILE HEADER CARD ──────────────────────────────────────────
          _buildProfileHeaderCard(settingsProv, settings, isDark),
          const SizedBox(height: 24),

          // A. APPEARANCE
          _sectionLabel('Appearance', Icons.palette_outlined, isDark),
          _buildThemeSelector(settingsProv, settings, isDark),
          const SizedBox(height: 24),

          // B. INTERACTION & HAPTIC FEEDBACK
          _sectionLabel('Interaction & Haptics', Icons.vibration_rounded, isDark),
          _buildHapticFeedbackCard(settingsProv, settings, isDark),
          const SizedBox(height: 24),

          // C. STUDENT & INSTITUTION
          _sectionLabel('Student & Institution', Icons.person_outline, isDark),
          _buildProfileForm(isDark),
          const SizedBox(height: 24),

          // D. ATTENDANCE TARGET
          _sectionLabel('Attendance Target', Icons.track_changes, isDark),
          _buildTargetCard(settingsProv, settings, isDark),
          const SizedBox(height: 24),

          // E. HOLIDAYS & OFF-DAYS
          _sectionLabel('Holidays & Off-Days', Icons.beach_access_outlined, isDark),
          _buildHolidaysCard(settingsProv, settings, isDark),
          const SizedBox(height: 24),

          // F. NOTIFICATIONS
          _sectionLabel('Notifications & Reminders', Icons.notifications_active_outlined, isDark),
          _buildNotificationsCard(settingsProv, settings, attendance, isDark),
          const SizedBox(height: 24),

          // G. DATA MANAGEMENT
          _sectionLabel('Data Management', Icons.save_alt_outlined, isDark),
          _buildDataManagementCard(attendance, settingsProv, isDark),
          const SizedBox(height: 24),

          // H. ABOUT
          _sectionLabel('About', Icons.info_outline, isDark),
          _buildAboutCard(isDark),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── PROFILE HEADER ──────────────────────────────────────────────────────
  Widget _buildProfileHeaderCard(SettingsProvider prov, dynamic settings, bool isDark) {
    final name = (settings.studentName as String).isNotEmpty
        ? settings.studentName as String
        : 'Student';
    final institution = (settings.institutionName as String).isNotEmpty
        ? settings.institutionName as String
        : null;
    final course = (settings.courseName as String).isNotEmpty
        ? settings.courseName as String
        : null;

    final imagePath = settings.profileImagePath as String?;
    final hasImage = imagePath != null && File(imagePath).existsSync();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2A2520), const Color(0xFF1E1C18)]
              : [AppColors.craftTeal.withAlpha(20), AppColors.lightCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorderStrong : AppColors.craftTeal.withAlpha(80),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 90 : 35),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showProfileImageSheet(context, prov, settings),
            child: Stack(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: AppColors.craftTeal.withAlpha(isDark ? 50 : 30),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.craftTeal, width: 2.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(50),
                        offset: const Offset(0, 3),
                        blurRadius: 6,
                      ),
                    ],
                    image: hasImage
                        ? DecorationImage(
                            image: FileImage(File(imagePath)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasImage
                      ? null
                      : const Icon(Icons.person_rounded, size: 34, color: AppColors.craftTeal),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.craftTeal,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                if (institution != null)
                  Text(
                    institution,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                if (course != null)
                  Text(
                    course,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    ),
                  ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _showProfileImageSheet(context, prov, settings),
                  child: const Text(
                    'Tap avatar to edit picture',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.craftTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── THEME SELECTOR ───────────────────────────────────────────────────────
  Widget _buildThemeSelector(SettingsProvider prov, dynamic settings, bool isDark) {
    final modes = [
      ('system', Icons.brightness_auto_rounded, 'System'),
      ('light', Icons.wb_sunny_rounded, 'Light'),
      ('dark', Icons.nights_stay_rounded, 'Dark'),
    ];

    return Row(
      children: modes.map((m) {
        final isSelected = settings.themeMode == m.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => prov.setThemeMode(m.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.craftTeal
                    : (isDark ? AppColors.darkCard : AppColors.lightCard),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppColors.craftTeal
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isSelected ? 60 : (isDark ? 50 : 20)),
                    blurRadius: isSelected ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    m.$2,
                    size: 24,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m.$3,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── HAPTIC FEEDBACK ─────────────────────────────────────────────────────
  Widget _buildHapticFeedbackCard(SettingsProvider prov, dynamic settings, bool isDark) {
    return PaperCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Haptic Vibration Feedback', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        subtitle: const Text('Tactile vibration when pressing buttons, stamping attendance, and navigating'),
        value: settings.hapticFeedbackEnabled as bool,
        activeTrackColor: AppColors.craftTeal,
        onChanged: (val) {
          prov.setHapticFeedback(val);
        },
      ),
    );
  }

  // ── PROFILE FORM ─────────────────────────────────────────────────────────
  Widget _buildProfileForm(bool isDark) {
    return PaperCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _styledTextField(_nameController, 'Student Name', 'e.g. Alex Morgan', Icons.person_outline),
          const SizedBox(height: 12),
          _styledTextField(_institutionController, 'College / Institution', 'e.g. Oxford Institute', Icons.school_outlined),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _styledTextField(_courseController, 'Course', 'e.g. Computer Sci.', Icons.book_outlined),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _styledTextField(_semesterController, 'Semester', 'e.g. Sem 5', Icons.access_time_outlined),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.craftTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            onPressed: _saveProfile,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Save Profile', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _styledTextField(TextEditingController ctrl, String label, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      ),
    );
  }

  // ── ATTENDANCE TARGET ─────────────────────────────────────────────────────
  Widget _buildTargetCard(SettingsProvider prov, dynamic settings, bool isDark) {
    return PaperCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Default Target:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.craftTeal,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${settings.defaultAttendanceTarget.toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.craftTeal,
              thumbColor: AppColors.craftTeal,
              overlayColor: AppColors.craftTeal.withAlpha(30),
              trackHeight: 4,
            ),
            child: Slider(
              value: settings.defaultAttendanceTarget,
              min: 50.0,
              max: 95.0,
              divisions: 9,
              label: '${settings.defaultAttendanceTarget.toInt()}%',
              onChanged: (val) => prov.setDefaultTarget(val),
            ),
          ),
          Text(
            'Subjects without specific targets will use this threshold.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── HOLIDAYS & OFF-DAYS ───────────────────────────────────────────────────
  Widget _buildHolidaysCard(SettingsProvider prov, dynamic settings, bool isDark) {
    final customList = (settings.customHolidaysList as List<String>);

    return PaperCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saturday Off Schedule',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure recurring Saturday holidays for your institution:',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),

          // Saturday pattern radio choices
          _saturdayRadioTile(
            title: '2nd & 4th Saturdays Off (Most Common)',
            value: 'second_fourth',
            groupValue: settings.saturdayHolidayPattern,
            onChanged: (v) => prov.setSaturdayHolidayPattern(v),
          ),
          _saturdayRadioTile(
            title: '1st & 3rd Saturdays Off',
            value: 'first_third',
            groupValue: settings.saturdayHolidayPattern,
            onChanged: (v) => prov.setSaturdayHolidayPattern(v),
          ),
          _saturdayRadioTile(
            title: 'All Saturdays Off (5-Day Week)',
            value: 'all_saturdays',
            groupValue: settings.saturdayHolidayPattern,
            onChanged: (v) => prov.setSaturdayHolidayPattern(v),
          ),
          _saturdayRadioTile(
            title: 'Working Every Saturday (No Saturdays Off)',
            value: 'none',
            groupValue: settings.saturdayHolidayPattern,
            onChanged: (v) => prov.setSaturdayHolidayPattern(v),
          ),

          const Divider(height: 24),

          // Custom Holiday Dates
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Declared Holiday Dates',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  Text(
                    '${customList.length} custom holiday date(s) added',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.craftTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    final ymd = AppDateUtils.formatDateYmd(picked);
                    await prov.addCustomHoliday(ymd);
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),

          if (customList.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: customList.map((ymd) {
                DateTime? dt;
                try {
                  dt = AppDateUtils.parseYmd(ymd);
                } catch (_) {}
                final label = dt != null ? AppDateUtils.formatShortDate(dt) : ymd;

                return Chip(
                  label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  backgroundColor: isDark ? const Color(0xFF2E2A25) : const Color(0xFFEBE5D8),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => prov.removeCustomHoliday(ymd),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _saturdayRadioTile({
    required String title,
    required String value,
    required String groupValue,
    required ValueChanged<String> onChanged,
  }) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: isSelected ? AppColors.craftTeal : Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.craftTeal : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── NOTIFICATIONS ─────────────────────────────────────────────────────────
  Widget _buildNotificationsCard(
      SettingsProvider prov, dynamic settings, AttendanceProvider attendance, bool isDark) {
    return PaperCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Class Start Reminders', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Interactive PRESENT / ABSENT notifications at class start'),
            value: settings.notificationsEnabled,
            activeTrackColor: AppColors.craftTeal,
            onChanged: (val) async {
              if (val) {
                await NotificationService.instance.requestPermissions();
                await NotificationService.instance.requestExactAlarmPermission();
              }
              await prov.updateNotificationPreferences(
                notificationsEnabled: val,
                advanceReminderEnabled: settings.advanceReminderEnabled,
                advanceReminderMinutes: settings.advanceReminderMinutes,
              );
              await attendance.rescheduleAllNotifications(prov.settings);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Advance Reminder', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Early reminder before class starts'),
            value: settings.advanceReminderEnabled,
            activeTrackColor: AppColors.craftTeal,
            onChanged: (val) async {
              if (val) {
                await NotificationService.instance.requestPermissions();
                await NotificationService.instance.requestExactAlarmPermission();
              }
              await prov.updateNotificationPreferences(
                notificationsEnabled: settings.notificationsEnabled,
                advanceReminderEnabled: val,
                advanceReminderMinutes: settings.advanceReminderMinutes,
              );
              await attendance.rescheduleAllNotifications(prov.settings);
            },
          ),
          if (settings.advanceReminderEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Reminder timing:'),
                  DropdownButton<int>(
                    value: settings.advanceReminderMinutes,
                    items: [5, 10, 15, 30]
                        .map((m) => DropdownMenuItem(value: m, child: Text('$m mins before')))
                        .toList(),
                    onChanged: (val) async {
                      if (val != null) {
                        await prov.updateNotificationPreferences(
                          notificationsEnabled: settings.notificationsEnabled,
                          advanceReminderEnabled: true,
                          advanceReminderMinutes: val,
                        );
                        await attendance.rescheduleAllNotifications(prov.settings);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── DATA MANAGEMENT ───────────────────────────────────────────────────────
  Widget _buildDataManagementCard(
      AttendanceProvider attendance, SettingsProvider settingsProv, bool isDark) {
    return PaperCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          _dataActionTile(
            icon: Icons.upload_file_rounded,
            iconColor: AppColors.craftIndigo,
            title: 'Import Timetable from CSV',
            subtitle: 'Bulk-import recurring schedule from a CSV file',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CsvImportScreen()),
              );
            },
          ),
          const Divider(height: 1),
          _dataActionTile(
            icon: Icons.table_chart_outlined,
            iconColor: AppColors.craftTeal,
            title: 'Export Attendance to CSV',
            subtitle: 'Save or share spreadsheet of attendance records',
            onTap: () async {
              final res = await BackupService.instance.exportToCsv();
              if (mounted && !res.success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res.message)),
                );
              }
            },
          ),
          const Divider(height: 1),
          _dataActionTile(
            icon: Icons.file_download_outlined,
            iconColor: AppColors.kraftBrown,
            title: 'Export JSON Backup',
            subtitle: 'Full backup of subjects, schedules & history',
            onTap: () async {
              final res = await BackupService.instance.exportToJson();
              if (mounted && !res.success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res.message)),
                );
              }
            },
          ),
          const Divider(height: 1),
          _dataActionTile(
            icon: Icons.restore_outlined,
            iconColor: AppColors.craftPlum,
            title: 'Import / Restore Backup',
            subtitle: 'Restore from a previously exported JSON backup',
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Restore Backup?'),
                  content: const Text(
                    'Restoring will replace your current records with the backup file data.\n\nContinue?',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.craftTeal),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Select File & Restore'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                final res = await BackupService.instance.pickAndRestoreJson();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res.message)),
                  );
                  if (res.success) {
                    await attendance.loadData();
                    await settingsProv.loadSettings();
                  }
                }
              }
            },
          ),
          const Divider(height: 1),
          _dataActionTile(
            icon: Icons.delete_forever,
            iconColor: AppColors.absent,
            title: 'Reset All Data',
            subtitle: 'Permanently wipe all records (cannot be undone)',
            titleColor: AppColors.absent,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset All Application Data?'),
                  content: const Text(
                    'This will permanently delete ALL subjects, schedules, and attendance records.\n\nThis cannot be undone.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.absent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Reset Everything'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await AppDatabase.instance.clearAllData();
                await attendance.loadData();
                await settingsProv.loadSettings();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All data has been reset.')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _dataActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: titleColor,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }

  // ── ABOUT ─────────────────────────────────────────────────────────────────
  Widget _buildAboutCard(bool isDark) {
    return PaperCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.craftTeal.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.craftTeal.withAlpha(80)),
            ),
            child: const Icon(Icons.auto_stories_rounded, color: AppColors.craftTeal, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attendance Tracker',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                Text(
                  'Version 1.0 • Personal Edition',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Offline-first • No accounts • No tracking',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SECTION LABEL ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.craftTeal),
          const SizedBox(width: 7),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
