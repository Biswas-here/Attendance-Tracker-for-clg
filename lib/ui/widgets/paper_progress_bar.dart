import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Retro segmented loading bar — matches reference image:
/// pill outline, bold diagonal-hatch fill on the left, clean empty right side.
class PaperLinearProgress extends StatelessWidget {
  final double? percentage;
  final double targetPercentage;
  final double height;
  final double borderRadius;
  final bool showTargetPin;

  const PaperLinearProgress({
    super.key,
    required this.percentage,
    this.targetPercentage = 75.0,
    this.height = 13.0,
    this.borderRadius = 6.0,
    this.showTargetPin = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meetsTarget = percentage != null && percentage! >= targetPercentage;
    final fillColor = percentage == null
        ? AppColors.unmarked
        : (meetsTarget ? AppColors.present : AppColors.absent);
    final val = percentage != null ? (percentage! / 100.0).clamp(0.0, 1.0) : 0.0;
    final targetVal = (targetPercentage / 100.0).clamp(0.0, 1.0);

    return SizedBox(
      height: height,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _RetroSegmentBarPainter(
            progress: val,
            targetProgress: targetVal,
            fillColor: fillColor,
            isDark: isDark,
            showTargetPin: showTargetPin && percentage != null,
            borderRadius: math.min(borderRadius, height / 2),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _RetroSegmentBarPainter extends CustomPainter {
  final double progress;
  final double targetProgress;
  final Color fillColor;
  final bool isDark;
  final bool showTargetPin;
  final double borderRadius;

  _RetroSegmentBarPainter({
    required this.progress,
    required this.targetProgress,
    required this.fillColor,
    required this.isDark,
    required this.showTargetPin,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    // 1. Empty track background
    final trackColor = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final trackPaint = Paint()..color = trackColor;
    canvas.drawRRect(rrect, trackPaint);

    // 2. Filled section with diagonal hatching (clipped to pill)
    if (progress > 0) {
      final fillWidth = size.width * progress;

      canvas.save();
      canvas.clipRRect(rrect);

      // Slight tinted background for the filled zone
      final bgColor = Color.lerp(fillColor, Colors.white, isDark ? 0.05 : 0.70)!;
      canvas.drawRect(Rect.fromLTWH(0, 0, fillWidth, size.height), Paint()..color = bgColor);

      // Bold diagonal hatch lines inside the fill zone only
      final hatchPaint = Paint()
        ..color = fillColor.withAlpha(isDark ? 180 : 200)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square;

      // Clip strictly to filled area
      canvas.clipRect(Rect.fromLTWH(0, 0, fillWidth, size.height));

      const slashStep = 7.0;
      for (double x = -size.height; x < fillWidth + size.height; x += slashStep) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          hatchPaint,
        );
      }

      canvas.restore();
    }

    // 3. Border outline — drawn on top (clean pill border)
    final borderColor = isDark ? AppColors.darkBorderStrong : fillColor.withAlpha(200);
    final borderPaint = Paint()
      ..color = progress > 0 ? borderColor : (isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRRect(rrect, borderPaint);

    // 4. Target pin needle
    if (showTargetPin && targetProgress > 0.05 && targetProgress < 0.98) {
      final targetX = size.width * targetProgress;

      final needlePaint = Paint()
        ..color = AppColors.kraftGold
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(targetX, 0), Offset(targetX, size.height), needlePaint);

      // Top arrow
      final arrowPath = Path()
        ..moveTo(targetX - 2.5, 0)
        ..lineTo(targetX + 2.5, 0)
        ..lineTo(targetX, 4.0)
        ..close();
      canvas.drawPath(arrowPath, Paint()..color = AppColors.kraftGold);
    }
  }

  @override
  bool shouldRepaint(covariant _RetroSegmentBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.targetProgress != targetProgress ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.isDark != isDark;
  }
}

class PaperCircularProgress extends StatefulWidget {
  final double? percentage;
  final double targetPercentage;
  final double size;
  final double strokeWidth;
  final bool animate;
  final int animTrigger;

  const PaperCircularProgress({
    super.key,
    required this.percentage,
    this.targetPercentage = 75.0,
    this.size = 140.0,
    this.strokeWidth = 12.0,
    this.animate = true,
    this.animTrigger = 0,
  });

  @override
  State<PaperCircularProgress> createState() => _PaperCircularProgressState();
}

class _PaperCircularProgressState extends State<PaperCircularProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _curvedAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _curvedAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    if (widget.animate && widget.percentage != null) {
      _animController.forward(from: 0.0);
    } else {
      _animController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant PaperCircularProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (((widget.percentage != oldWidget.percentage) ||
         (widget.animTrigger != oldWidget.animTrigger) ||
         (widget.animate && !oldWidget.animate)) &&
        widget.animate) {
      if (widget.percentage != null) {
        _animController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meetsTarget = widget.percentage != null && widget.percentage! >= widget.targetPercentage;
    final progressColor = widget.percentage == null
        ? AppColors.unmarked
        : (meetsTarget ? AppColors.present : AppColors.absent);

    final trackColor = isDark ? const Color(0xFF33302B) : const Color(0xFFECE7DC);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _curvedAnim,
        builder: (context, _) {
          final animFactor = widget.animate ? _curvedAnim.value : 1.0;
          final currentPct = widget.percentage != null ? widget.percentage! * animFactor : null;
          final progressVal = currentPct != null ? (currentPct / 100.0).clamp(0.0, 1.0) : 0.0;

          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _PaperCircularProgressPainter(
                    progress: progressVal,
                    strokeWidth: widget.strokeWidth,
                    trackColor: trackColor,
                    progressColor: progressColor,
                  ),
                ),
                // Inner text content counting up
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentPct != null ? '${currentPct.toStringAsFixed(1)}%' : '--',
                      style: TextStyle(
                        fontSize: widget.size * 0.22,
                        fontWeight: FontWeight.w900,
                        color: progressColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'TARGET ${widget.targetPercentage.toInt()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PaperCircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  const _PaperCircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 1. Draw smooth background track circle (full 360 degree ring)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Draw smooth continuous single progress arc (starts at 12 o'clock / -pi/2)
    if (progress >= 0.999) {
      final fullPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, fullPaint);
    } else if (progress > 0) {
      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PaperCircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

