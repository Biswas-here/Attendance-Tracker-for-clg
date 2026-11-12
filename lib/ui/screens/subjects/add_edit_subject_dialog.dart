import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/subject.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/attendance_provider.dart';

class AddEditSubjectDialog extends StatefulWidget {
  final Subject? subjectToEdit;

  const AddEditSubjectDialog({super.key, this.subjectToEdit});

  @override
  State<AddEditSubjectDialog> createState() => _AddEditSubjectDialogState();
}

class _AddEditSubjectDialogState extends State<AddEditSubjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _teacherController;
  late TextEditingController _roomController;
  late TextEditingController _targetController;
  late int _selectedColorValue;
  bool _allowDuplicate = false;

  @override
  void initState() {
    super.initState();
    final sub = widget.subjectToEdit;
    _nameController = TextEditingController(text: sub?.name ?? '');
    _teacherController = TextEditingController(text: sub?.teacher ?? '');
    _roomController = TextEditingController(text: sub?.room ?? '');
    _targetController = TextEditingController(
      text: sub?.targetPercentage != null ? sub!.targetPercentage!.toStringAsFixed(0) : '',
    );
    _selectedColorValue = sub?.colorValue ?? AppColors.subjectTagColors.first.toARGB32();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _roomController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final attendance = context.read<AttendanceProvider>();
    final isEditing = widget.subjectToEdit != null;

    double? targetVal;
    if (_targetController.text.trim().isNotEmpty) {
      targetVal = double.tryParse(_targetController.text.trim());
    }

    final teacherText = _teacherController.text.trim();
    final roomText = _roomController.text.trim();

    if (isEditing) {
      final updated = Subject(
        id: widget.subjectToEdit!.id,
        name: _nameController.text.trim(),
        code: widget.subjectToEdit!.code,
        teacher: teacherText.isEmpty ? null : teacherText,
        room: roomText.isEmpty ? null : roomText,
        targetPercentage: targetVal,
        colorValue: _selectedColorValue,
        createdAt: widget.subjectToEdit!.createdAt,
      );
      await attendance.updateSubject(updated);
      if (mounted) Navigator.pop(context);
    } else {
      final error = await attendance.addSubject(
        name: _nameController.text.trim(),
        teacher: _teacherController.text.trim().isEmpty ? null : _teacherController.text.trim(),
        room: _roomController.text.trim().isEmpty ? null : _roomController.text.trim(),
        targetPercentage: targetVal,
        colorValue: _selectedColorValue,
        allowDuplicate: _allowDuplicate,
      );

      if (error == 'duplicate') {
        if (!mounted) return;
        final allow = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Duplicate Subject Name'),
            content: Text(
              'A subject named "${_nameController.text.trim()}" already exists. Do you want to add it anyway?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.craftTeal),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Allow Duplicate'),
              ),
            ],
          ),
        );

        if (allow == true) {
          _allowDuplicate = true;
          _submit();
        }
        return;
      }

      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.subjectToEdit != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Text(
        isEditing ? 'Edit Subject' : 'Add New Subject',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Subject Name *',
                  hintText: 'e.g. Mathematics, Physics',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.menu_book_rounded, size: 20),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a subject name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _teacherController,
                decoration: const InputDecoration(
                  labelText: 'Teacher Name (Optional)',
                  hintText: 'e.g. Prof. Alan Turing',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roomController,
                decoration: const InputDecoration(
                  labelText: 'Room Number (Optional)',
                  hintText: 'e.g. Lab 3, 101, Audi-2',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.meeting_room_outlined, size: 20),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Attendance Target % (Optional)',
                  hintText: 'Leave empty to use default target (75%)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.track_changes_rounded, size: 20),
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tag Color:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppColors.subjectTagColors.map((color) {
                  final isSelected = _selectedColorValue == color.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorValue = color.toARGB32()),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2.5)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withAlpha(120),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.craftTeal,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: Text(isEditing ? 'Save Changes' : 'Create Subject'),
        ),
      ],
    );
  }
}

