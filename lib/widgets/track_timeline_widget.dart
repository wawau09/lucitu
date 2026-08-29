import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/models/planner_model.dart';

/// A race-track style timeline widget that displays travel events
/// along a serpentine path with colored dot markers and distinct colored connecting lines.
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '타임라인 일정',
            style: GoogleFonts.notoSansKr(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
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
                  final event = painter.findTappedEvent(details.localPosition);
                  if (event != null && onEventTap != null) {
                    onEventTap!(event);
                  }
                },
                child: CustomPaint(
                  size: Size(w, painter.totalHeight),
                  painter: painter,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Node representation for each dot along the track
// ---------------------------------------------------------------------------
enum _NodeType { start, end, single }

class _TrackNode {
  final TravelEvent event;
  final String time;
  final String title;
  final _NodeType type;
  final Color color;
  final int eventIndex;

  const _TrackNode({
    required this.event,
    required this.time,
    required this.title,
    required this.type,
    required this.color,
    required this.eventIndex,
  });

  bool get isEnd => type == _NodeType.end;
}

// ---------------------------------------------------------------------------
// Custom painter that draws the full track, colored connecting segments, dots, and labels
// ---------------------------------------------------------------------------
class _TrackPainter extends CustomPainter {
  final List<TravelEvent> events;
  final double width;
  final bool isDark;
  late final List<_TrackNode> nodes;

  // ---- Layout constants ----
  static const int itemsPerRow = 3;
  static const double horizontalPadding = 40.0;
  static const double turnRadius = 18.0;
  static const double topPadding = 32.0;
  static const double bottomPadding = 48.0;
  static const double rowSpacing = 92.0;
  static const double dotRadius = 7.0;
  static const double baseTrackStrokeWidth = 3.0;
  static const double segmentStrokeWidth = 4.5;

  // Curated vibrant harmonious color palette for event segments
  static const List<Color> _palette = [
    Color(0xFFFF6B4A), // Coral Red
    Color(0xFF3B82F6), // Vibrant Blue
    Color(0xFF10B981), // Emerald Green
    Color(0xFF8B5CF6), // Royal Purple
    Color(0xFFF59E0B), // Warm Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFF6366F1), // Indigo
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
  ];

  _TrackPainter({
    required this.events,
    required this.width,
    required this.isDark,
  }) {
    final list = <_TrackNode>[];
    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      final eventColor = _palette[i % _palette.length];
      final hasEndTime = event.endTime != null &&
          event.endTime!.isNotEmpty &&
          event.endTime != event.startTime;

      if (hasEndTime) {
        // 1. 시작 시간 점 (시작 시간만 단독 표시, ~ 없음)
        list.add(_TrackNode(
          event: event,
          time: _formatTo12Hour(event.startTime),
          title: event.title,
          type: _NodeType.start,
          color: eventColor,
          eventIndex: i,
        ));

        // 2. 종료 시간 점 (종료 시간만 단독 표시, ~ 없음)
        list.add(_TrackNode(
          event: event,
          time: _formatTo12Hour(event.endTime!),
          title: '${event.title} (종료)',
          type: _NodeType.end,
          color: eventColor,
          eventIndex: i,
        ));
      } else {
        // 단일 시간 점
        list.add(_TrackNode(
          event: event,
          time: _formatTo12Hour(event.startTime),
          title: event.title,
          type: _NodeType.single,
          color: eventColor,
          eventIndex: i,
        ));
      }
    }
    nodes = list;
  }

  // Base background track color
  Color get _trackColor => isDark
      ? Colors.white.withOpacity(0.12)
      : const Color(0xFFE5E5EA);

  Color get _timeTextColor => isDark
      ? Colors.white
      : const Color(0xFF1C1C1E);

  Color get _titleTextColor => isDark
      ? Colors.white.withOpacity(0.75)
      : const Color(0xFF48484A);

  int get _rowCount =>
      nodes.isEmpty ? 0 : (nodes.length / itemsPerRow).ceil();

  double get totalHeight {
    if (_rowCount == 0) return 0;
    return topPadding + (_rowCount - 1) * rowSpacing + bottomPadding;
  }

  double get _leftX => horizontalPadding;
  double get _rightX => width - horizontalPadding;
  double get _usableWidth => _rightX - _leftX;

  double _trackY(int row) => topPadding + row * rowSpacing;

  /// Compute the display position (x, y) for node at [index] using fixed slots.
  Offset _dotPosition(int index) {
    final row = index ~/ itemsPerRow;
    final col = index % itemsPerRow; // 0, 1, 2
    final isReversed = row.isOdd;

    final displayCol = isReversed ? (itemsPerRow - 1 - col) : col;
    final x = _leftX + displayCol * (_usableWidth / (itemsPerRow - 1));

    return Offset(x, _trackY(row));
  }

  /// Return the travel event whose dot was tapped, or null.
  TravelEvent? findTappedEvent(Offset position) {
    for (int i = 0; i < nodes.length; i++) {
      if ((position - _dotPosition(i)).distance < 24) return nodes[i].event;
    }
    return null;
  }

  // ---- Paint entry point ----
  @override
  void paint(Canvas canvas, Size size) {
    if (_rowCount == 0) return;
    _drawBaseTrackPath(canvas);
    _drawColoredSegments(canvas);
    _drawEventsOnTrack(canvas);
  }

  // ---- Base background track (neutral guide line) ----
  void _drawBaseTrackPath(Canvas canvas) {
    final paint = Paint()
      ..color = _trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseTrackStrokeWidth
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

  // ---- Draw colorful connecting lines between dots ----
  void _drawColoredSegments(Canvas canvas) {
    if (nodes.length < 2) return;

    for (int i = 0; i < nodes.length - 1; i++) {
      final fromNode = nodes[i];
      final toNode = nodes[i + 1];

      // Segment color decision:
      // If connecting start -> end of the same event: use that event's vibrant color!
      // If connecting between different events (interval/transit): use a distinct transit color from palette!
      Color segmentColor;
      if (fromNode.eventIndex == toNode.eventIndex &&
          fromNode.type == _NodeType.start &&
          toNode.type == _NodeType.end) {
        segmentColor = fromNode.color;
      } else {
        // Distinct color for transit between events
        final transitColorIndex = (fromNode.eventIndex + 5) % _palette.length;
        segmentColor = _palette[transitColorIndex];
      }

      final segmentPath = _buildSegmentPath(i, i + 1);

      // Glow / Shadow behind the colored line
      canvas.drawPath(
        segmentPath,
        Paint()
          ..color = segmentColor.withOpacity(isDark ? 0.35 : 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = segmentStrokeWidth + 4.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );

      // Main colored stroke
      canvas.drawPath(
        segmentPath,
        Paint()
          ..color = segmentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = segmentStrokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  /// Build a serpentine path strictly between node [fromIndex] and [toIndex] (where toIndex == fromIndex + 1).
  Path _buildSegmentPath(int fromIndex, int toIndex) {
    final fromPos = _dotPosition(fromIndex);
    final toPos = _dotPosition(toIndex);

    final fromRow = fromIndex ~/ itemsPerRow;
    final toRow = toIndex ~/ itemsPerRow;

    final path = Path();
    path.moveTo(fromPos.dx, fromPos.dy);

    if (fromRow == toRow) {
      // Straight horizontal segment on the same row
      path.lineTo(toPos.dx, toPos.dy);
    } else {
      // Row transition (fromIndex is at the end of fromRow, toIndex is at start of toRow)
      final y1 = _trackY(fromRow);
      final y2 = _trackY(toRow);

      if (fromRow.isEven) {
        // Right side U-turn
        _appendRightUTurn(path, _rightX, y1, y2);
      } else {
        // Left side U-turn
        _appendLeftUTurn(path, _leftX, y1, y2);
      }
    }

    return path;
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

    for (int i = 0; i < nodes.length; i++) {
      final pos = _dotPosition(i);
      final node = nodes[i];
      final dotColor = node.color;

      // Ambient glow
      canvas.drawCircle(
        pos,
        dotRadius + 5,
        Paint()
          ..color = dotColor.withOpacity(isDark ? 0.35 : 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );

      // Solid outer dot
      canvas.drawCircle(pos, dotRadius, Paint()..color = dotColor);

      // White inner core (solid inner dot for start/single, ring for end)
      if (node.isEnd) {
        canvas.drawCircle(
          pos,
          dotRadius - 2.5,
          Paint()..color = isDark ? const Color(0xFF1C1C1E) : Colors.white,
        );
        canvas.drawCircle(
          pos,
          1.8,
          Paint()..color = dotColor,
        );
      } else {
        canvas.drawCircle(
          pos,
          2.6,
          Paint()..color = Colors.white,
        );
      }

      // Time label above dot (single time point: e.g. "10:00am" or "11:30am", NO ~)
      _paintText(
        canvas,
        text: node.time,
        position: Offset(pos.dx, pos.dy - dotRadius - 6),
        fontSize: 10.0,
        fontWeight: FontWeight.w700,
        color: _timeTextColor,
        maxWidth: 100,
        anchorBottom: true,
      );

      // Event title below dot
      _paintText(
        canvas,
        text: node.title,
        position: Offset(pos.dx, pos.dy + dotRadius + 6),
        fontSize: 10.5,
        fontWeight: node.isEnd ? FontWeight.w500 : FontWeight.w700,
        color: node.isEnd
            ? (isDark ? Colors.white70 : const Color(0xFF6E6E73))
            : _titleTextColor,
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
          height: 1.25,
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

  /// Convert "HH:mm" → "h:mmam/pm" (e.g. "13:30" → "1:30pm", "09:00" → "9:00am").
  static String _formatTo12Hour(String time24) {
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

