import 'dart:math';
import 'package:flutter/material.dart';
import 'package:placelist/models/planner_model.dart';

/// A race-track style timeline widget that displays travel events
/// along a serpentine path with yellow dot markers.
///
/// Each row holds up to 3 events. Odd rows reverse direction (R→L)
/// and are connected by U-turn arcs, mimicking a racing circuit.
class TrackTimelineWidget extends StatelessWidget {
  final List<TravelEvent> events;
  final bool isDark;
  final void Function(TravelEvent)? onEventTap;

  const TrackTimelineWidget({
    super.key,
    required this.events,
    required this.isDark,
    this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final painter = _TrackPainter(
            events: events,
            width: w,
            isDark: isDark,
          );
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final idx = painter.findTappedEventIndex(details.localPosition);
              if (idx != null && onEventTap != null) {
                onEventTap!(events[idx]);
              }
            },
            child: CustomPaint(
              size: Size(w, painter.totalHeight),
              painter: painter,
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom painter that draws the full track, dots, and text labels
// ---------------------------------------------------------------------------
class _TrackPainter extends CustomPainter {
  final List<TravelEvent> events;
  final double width;
  final bool isDark;

  // ---- Layout constants ----
  static const int itemsPerRow = 3;
  static const double horizontalPadding = 40.0;
  static const double turnRadius = 18.0;
  static const double topPadding = 32.0;
  static const double bottomPadding = 48.0;
  static const double rowSpacing = 92.0;
  static const double dotRadius = 7.0;
  static const double trackStrokeWidth = 3.0;

  _TrackPainter({
    required this.events,
    required this.width,
    required this.isDark,
  });

  // Color tokens based on theme
  Color get _trackColor => isDark
      ? Colors.white.withOpacity(0.22)
      : const Color(0xFFC7C7CC);

  Color get _dotColor => isDark
      ? const Color(0xFFFFB300)
      : const Color(0xFFFF9500);

  Color get _timeTextColor => isDark
      ? Colors.white
      : const Color(0xFF1C1C1E);

  Color get _titleTextColor => isDark
      ? Colors.white.withOpacity(0.75)
      : const Color(0xFF48484A);

  int get _rowCount =>
      events.isEmpty ? 0 : (events.length / itemsPerRow).ceil();

  double get totalHeight {
    if (_rowCount == 0) return 0;
    return topPadding + (_rowCount - 1) * rowSpacing + bottomPadding;
  }

  double get _leftX => horizontalPadding;
  double get _rightX => width - horizontalPadding;
  double get _usableWidth => _rightX - _leftX;

  double _trackY(int row) => topPadding + row * rowSpacing;

  /// Compute the display position (x, y) for event at [index].
  Offset _dotPosition(int index) {
    final row = index ~/ itemsPerRow;
    final posInRow = index % itemsPerRow;
    final itemsInThisRow =
        min(itemsPerRow, events.length - row * itemsPerRow);
    final isReversed = row.isOdd;

    final displayPos =
        isReversed ? (itemsInThisRow - 1 - posInRow) : posInRow;

    double x;
    if (itemsInThisRow <= 1) {
      x = _leftX + _usableWidth / 2;
    } else {
      x = _leftX + displayPos * _usableWidth / (itemsInThisRow - 1);
    }

    return Offset(x, _trackY(row));
  }

  /// Return the event index whose dot was tapped, or null.
  int? findTappedEventIndex(Offset position) {
    for (int i = 0; i < events.length; i++) {
      if ((position - _dotPosition(i)).distance < 22) return i;
    }
    return null;
  }

  // ---- Paint entry point ----
  @override
  void paint(Canvas canvas, Size size) {
    if (_rowCount == 0) return;
    _drawTrackPath(canvas);
    _drawEventsOnTrack(canvas);
  }

  // ---- Track serpentine path ----
  void _drawTrackPath(Canvas canvas) {
    final paint = Paint()
      ..color = _trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(_leftX, _trackY(0))
      ..lineTo(_rightX, _trackY(0));

    for (int row = 0; row < _rowCount - 1; row++) {
      final y = _trackY(row);
      final nextY = _trackY(row + 1);

      if (row.isEven) {
        _appendRightUTurn(path, _rightX, y, nextY);
        path.lineTo(_leftX, nextY);
      } else {
        _appendLeftUTurn(path, _leftX, y, nextY);
        path.lineTo(_rightX, nextY);
      }
    }

    canvas.drawPath(path, paint);
  }

  /// Quarter-arc → vertical line → quarter-arc on the right side.
  void _appendRightUTurn(Path path, double x, double y1, double y2) {
    final gap = y2 - y1;
    if (gap <= 2 * turnRadius) {
      path.arcToPoint(Offset(x, y2),
          radius: Radius.circular(gap / 2), clockwise: true);
    } else {
      path.arcToPoint(Offset(x + turnRadius, y1 + turnRadius),
          radius: Radius.circular(turnRadius), clockwise: true);
      path.lineTo(x + turnRadius, y2 - turnRadius);
      path.arcToPoint(Offset(x, y2),
          radius: Radius.circular(turnRadius), clockwise: true);
    }
  }

  /// Quarter-arc → vertical line → quarter-arc on the left side.
  void _appendLeftUTurn(Path path, double x, double y1, double y2) {
    final gap = y2 - y1;
    if (gap <= 2 * turnRadius) {
      path.arcToPoint(Offset(x, y2),
          radius: Radius.circular(gap / 2), clockwise: false);
    } else {
      path.arcToPoint(Offset(x - turnRadius, y1 + turnRadius),
          radius: Radius.circular(turnRadius), clockwise: false);
      path.lineTo(x - turnRadius, y2 - turnRadius);
      path.arcToPoint(Offset(x, y2),
          radius: Radius.circular(turnRadius), clockwise: false);
    }
  }

  // ---- Dots & text labels ----
  void _drawEventsOnTrack(Canvas canvas) {
    final maxTextWidth = _usableWidth / itemsPerRow + 8;

    for (int i = 0; i < events.length; i++) {
      final pos = _dotPosition(i);
      final event = events[i];

      // Ambient glow
      canvas.drawCircle(
        pos,
        dotRadius + 5,
        Paint()
          ..color = _dotColor.withOpacity(isDark ? 0.22 : 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Solid dot
      canvas.drawCircle(pos, dotRadius, Paint()..color = _dotColor);

      // Specular highlight
      canvas.drawCircle(
        Offset(pos.dx - 1.5, pos.dy - 2),
        2.2,
        Paint()..color = Colors.white.withOpacity(isDark ? 0.6 : 0.8),
      );

      // Time label above dot
      _paintText(
        canvas,
        text: _formatTo12Hour(event.startTime),
        position: Offset(pos.dx, pos.dy - dotRadius - 6),
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: _timeTextColor,
        maxWidth: 80,
        anchorBottom: true,
      );

      // Event title below dot
      _paintText(
        canvas,
        text: event.title,
        position: Offset(pos.dx, pos.dy + dotRadius + 6),
        fontSize: 10.0,
        fontWeight: FontWeight.w600,
        color: _titleTextColor,
        maxWidth: maxTextWidth,
        anchorBottom: false,
      );
    }
  }

  // ---- Text helpers ----
  void _paintText(
    Canvas canvas, {
    required String text,
    required Offset position,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    required double maxWidth,
    required bool anchorBottom,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: 1.3,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '\u2026',
    )..layout(maxWidth: maxWidth);

    final x = position.dx - painter.width / 2;
    final y = anchorBottom ? position.dy - painter.height : position.dy;
    painter.paint(canvas, Offset(x, y));
  }

  /// Convert "HH:mm" → "h:mmam/pm" (e.g. "13:30" → "1:30pm").
  String _formatTo12Hour(String time24) {
    if (time24.isEmpty) return '';
    final parts = time24.split(':');
    if (parts.length < 2) return time24;
    int hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final suffix = hour >= 12 ? 'pm' : 'am';
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }
    return '$hour:$minute$suffix';
  }

  @override
  bool shouldRepaint(covariant _TrackPainter oldDelegate) {
    return !identical(oldDelegate.events, events) ||
        oldDelegate.width != width ||
        oldDelegate.isDark != isDark;
  }
}
