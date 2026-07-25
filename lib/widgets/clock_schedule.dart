import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/plan.dart';

class ClockScheduleWidget extends StatefulWidget {
  final List<PlanItem> items;
  final Function(PlanItem) onItemTap;

  const ClockScheduleWidget({
    super.key,
    required this.items,
    required this.onItemTap,
  });

  @override
  State<ClockScheduleWidget> createState() => _ClockScheduleWidgetState();
}

class _ClockScheduleWidgetState extends State<ClockScheduleWidget> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onTapUp: (details) {
          if (widget.items.isEmpty) return;
          
          final center = Offset(context.size!.width / 2, context.size!.height / 2);
          final dx = details.localPosition.dx - center.dx;
          final dy = details.localPosition.dy - center.dy;
          
          // Calculate angle from 12 o'clock (top) clockwise
          double angle = atan2(dy, dx) + pi / 2;
          if (angle < 0) angle += 2 * pi;
          
          final tappedTime = (angle / (2 * pi)) * 24; // 0 to 24
          
          // Find matching item
          for (final item in widget.items) {
             final start = _timeToDouble(item.startTime);
             var end = _timeToDouble(item.endTime ?? item.startTime);
             if (start == end) end = start + 1;
             
             if (start <= end) {
                 if (tappedTime >= start && tappedTime <= end) {
                     widget.onItemTap(item);
                     return;
                 }
             } else {
                 // spans midnight
                 if (tappedTime >= start || tappedTime <= end) {
                     widget.onItemTap(item);
                     return;
                 }
             }
          }
        },
        child: CustomPaint(
          painter: ClockSchedulePainter(items: widget.items, isDark: isDark),
        ),
      ),
    );
  }

  double _timeToDouble(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 0;
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final h = double.tryParse(parts[0]) ?? 0;
      final m = double.tryParse(parts[1]) ?? 0;
      return h + (m / 60.0);
    }
    return 0;
  }
}

class ClockSchedulePainter extends CustomPainter {
  final List<PlanItem> items;
  final bool isDark;

  ClockSchedulePainter({required this.items, this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * 0.85;

    // Background circle
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF1C1C1E) : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final borderPaint = Paint()
      ..color = isDark ? Colors.white24 : const Color(0xFFE8E1D9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);

    // Draw slices
    final colors = [
      const Color(0xFFFDE68A), // yellow
      const Color(0xFFFECACA), // red
      const Color(0xFFBFDBFE), // blue
      const Color(0xFFA7F3D0), // green
      const Color(0xFFE9D5FF), // purple
      const Color(0xFFFBCFE8), // pink
    ];

    int colorIndex = 0;
    for (final item in items) {
      final start = _timeToDouble(item.startTime);
      var end = _timeToDouble(item.endTime ?? item.startTime);
      if (start == end) end = start + 1; // Default 1 hour if no end time
      
      var startAngle = (start / 24) * 2 * pi - pi / 2;
      var sweepAngle = ((end - start) / 24) * 2 * pi;
      if (sweepAngle < 0) sweepAngle += 2 * pi;

      Color sliceColor;
      if (item.color != null) {
        sliceColor = Color(int.parse(item.color!.substring(1, 7), radix: 16) + 0xFF000000);
      } else {
        sliceColor = colors[colorIndex % colors.length];
        colorIndex++;
      }

      final slicePaint = Paint()
        ..color = sliceColor.withValues(alpha: isDark ? 0.70 : 0.85)
        ..style = PaintingStyle.fill;
        
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        slicePaint,
      );

      // Draw item title inside the arc if it's large enough
      if (sweepAngle > 0.05) {
        final midAngle = startAngle + sweepAngle / 2;
        final textRadius = radius * 0.65;
        final tx = center.dx + textRadius * cos(midAngle);
        final ty = center.dy + textRadius * sin(midAngle);

        final textSpan = TextSpan(
          text: item.title,
          style: GoogleFonts.notoSans(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLines: 2,
        );
        textPainter.layout(maxWidth: radius * 0.8);
        
        // Background for text to make it readable
        final bgRect = Rect.fromCenter(
          center: Offset(tx, ty),
          width: textPainter.width + 8,
          height: textPainter.height + 4,
        );
        final textBgPaint = Paint()
          ..color = isDark
              ? const Color(0xFF2C2C2E).withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(4)), textBgPaint);

        textPainter.paint(
            canvas, Offset(tx - textPainter.width / 2, ty - textPainter.height / 2));
      }
    }

    // Draw lines and ticks
    final linePaint = Paint()
      ..color = isDark ? Colors.white24 : const Color(0xFFE8E1D9)
      ..strokeWidth = 1;
      
    final textStyle = GoogleFonts.notoSans(
      color: isDark ? Colors.white54 : Colors.grey.shade600,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    for (int i = 0; i < 24; i++) {
      final angle = (i / 24) * 2 * pi - pi / 2;
      
      final isMajor = i % 6 == 0;
      final innerRadius = isMajor ? radius * 0.9 : radius * 0.95;
      
      final p1 = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      final p2 = Offset(
        center.dx + innerRadius * cos(angle),
        center.dy + innerRadius * sin(angle),
      );
      canvas.drawLine(p1, p2, linePaint);

      // Draw numbers for every 3 hours
      if (i % 3 == 0) {
        final textRadius = radius + 18;
        final tx = center.dx + textRadius * cos(angle);
        final ty = center.dy + textRadius * sin(angle);

        final textPainter = TextPainter(
          text: TextSpan(text: '$i', style: textStyle),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
            canvas, Offset(tx - textPainter.width / 2, ty - textPainter.height / 2));
      }
    }
    
    // Draw center dot
    canvas.drawCircle(center, 4, Paint()..color = isDark ? const Color(0xFF64B5F6) : const Color(0xFF3267A2));
  }

  double _timeToDouble(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 0;
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final h = double.tryParse(parts[0]) ?? 0;
      final m = double.tryParse(parts[1]) ?? 0;
      return h + (m / 60.0);
    }
    return 0;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
