import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/plan.dart';

/// 일정을 이미지로 캡처하기 위한 공유 카드 위젯.
///
/// [RepaintBoundary]의 [key]를 통해 바깥에서 캡처하기 위해
/// [repaintKey]를 반드시 전달하세요.
class PlanShareCard extends StatelessWidget {
  final GlobalKey repaintKey;
  final PlanSummary plan;
  final List<PlanItem> items;

  const PlanShareCard({
    super.key,
    required this.repaintKey,
    required this.plan,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintKey,
      child: _ShareCardContent(plan: plan, items: items),
    );
  }
}

// ─────────────────────────────────────────────
// 카드 본체 — 외부에서 캡처되는 실제 영역
// ─────────────────────────────────────────────
class _ShareCardContent extends StatelessWidget {
  final PlanSummary plan;
  final List<PlanItem> items;

  const _ShareCardContent({required this.plan, required this.items});

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(plan.planDate);

    return Container(
      width: 360,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1035), // 딥 퍼플
            Color(0xFF2D1B5E), // 보라
            Color(0xFF4A1942), // 다크 마젠타
            Color(0xFF1E0B2C), // 딥 다크
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // 배경 장식 — 별빛 느낌
          ..._buildStarDecorations(),
          // 배경 원 장식
          ..._buildCircleDecorations(),

          Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 헤더 ──
                _buildHeader(dateStr),
                const SizedBox(height: 24),

                // ── 시계 위젯 ──
                _buildClock(),
                const SizedBox(height: 20),

                // ── 아이템 목록 ──
                if (items.isNotEmpty) ...[
                  _buildItemList(),
                  const SizedBox(height: 20),
                ],

                // ── 워터마크 ──
                _buildWatermark(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 헤더 영역 ──
  Widget _buildHeader(String dateStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF9D8FFF).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('✨', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    '나의 하루',
                    style: GoogleFonts.notoSans(
                      fontSize: 11,
                      color: const Color(0xFFD4CAFF),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          plan.name,
          style: GoogleFonts.notoSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.2,
            letterSpacing: -0.5,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 13,
              color: Color(0xFFB39DDB),
            ),
            const SizedBox(width: 5),
            Text(
              dateStr,
              style: GoogleFonts.notoSans(
                fontSize: 13,
                color: const Color(0xFFB39DDB),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF7B68CB),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${items.length}개의 일정',
                style: GoogleFonts.notoSans(
                  fontSize: 13,
                  color: const Color(0xFFB39DDB),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ── 원형 시계 위젯 ──
  Widget _buildClock() {
    return Center(
      child: SizedBox(
        width: 260,
        height: 260,
        child: CustomPaint(
          painter: _ShareClockPainter(items: items),
        ),
      ),
    );
  }

  // ── 아이템 목록 (최대 4개) ──
  Widget _buildItemList() {
    final displayItems = items.take(4).toList();
    final hasMore = items.length > 4;
    final itemColors = [
      const Color(0xFFA78BFA),
      const Color(0xFF60A5FA),
      const Color(0xFF34D399),
      const Color(0xFFFBBF24),
      const Color(0xFFF87171),
      const Color(0xFF818CF8),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...displayItems.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final color = itemColors[i % itemColors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (item.startTime != null)
                  Text(
                    '${item.startTime!.substring(0, 5)}  ',
                    style: GoogleFonts.notoSans(
                      fontSize: 11,
                      color: const Color(0xFF9D8FFF),
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                Expanded(
                  child: Text(
                    item.title,
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 2),
            child: Text(
              '+${items.length - 4}개 더',
              style: GoogleFonts.notoSans(
                fontSize: 11,
                color: const Color(0xFF7B68CB),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  // ── 워터마크 ──
  Widget _buildWatermark() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 1,
          width: 40,
          color: Colors.white.withValues(alpha: 0.12),
        ),
        const SizedBox(width: 10),
        Text(
          'made with  Loci 🌸',
          style: GoogleFonts.notoSans(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.4),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 1,
          width: 40,
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ],
    );
  }

  // ── 배경 장식 — 별빛 ──
  List<Widget> _buildStarDecorations() {
    final positions = [
      const Offset(20, 15),
      const Offset(300, 40),
      const Offset(340, 120),
      const Offset(50, 200),
      const Offset(310, 300),
      const Offset(30, 380),
      const Offset(320, 450),
      const Offset(80, 500),
    ];
    return positions.map((pos) {
      return Positioned(
        left: pos.dx,
        top: pos.dy,
        child: Container(
          width: 2,
          height: 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
      );
    }).toList();
  }

  // ── 배경 장식 — 반투명 원 ──
  List<Widget> _buildCircleDecorations() {
    return [
      Positioned(
        top: -60,
        right: -60,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
          ),
        ),
      ),
      Positioned(
        bottom: -40,
        left: -40,
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF9C27B0).withValues(alpha: 0.08),
          ),
        ),
      ),
    ];
  }

  String _formatDate(DateTime date) {
    const months = [
      '1월', '2월', '3월', '4월', '5월', '6월',
      '7월', '8월', '9월', '10월', '11월', '12월',
    ];
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = weekdays[date.weekday - 1];
    return '${date.year}년 ${months[date.month - 1]} ${date.day}일 ($wd)';
  }
}

// ─────────────────────────────────────────────
// 공유 카드 전용 시계 Painter (다크 테마 고정)
// ─────────────────────────────────────────────
class _ShareClockPainter extends CustomPainter {
  final List<PlanItem> items;

  _ShareClockPainter({required this.items});

  static const _sliceColors = [
    Color(0xFFA78BFA), // 보라
    Color(0xFF60A5FA), // 파랑
    Color(0xFF34D399), // 민트
    Color(0xFFFBBF24), // 노랑
    Color(0xFFF87171), // 빨강
    Color(0xFF818CF8), // 인디고
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * 0.82;

    // ── 외곽 글로우 ──
    final glowPaint = Paint()
      ..color = const Color(0xFF6C63FF).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, radius + 8, glowPaint);

    // ── 배경 원 ──
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF12082A),
    );

    // ── 동심원 가이드 라인 ──
    for (final r in [radius * 0.4, radius * 0.7]) {
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // ── 아이템 슬라이스 ──
    int colorIndex = 0;
    for (final item in items) {
      final start = _timeToDouble(item.startTime);
      var end = _timeToDouble(item.endTime ?? item.startTime);
      if (start == end) end = start + 1;

      var startAngle = (start / 24) * 2 * pi - pi / 2;
      var sweepAngle = ((end - start) / 24) * 2 * pi;
      if (sweepAngle < 0) sweepAngle += 2 * pi;

      Color sliceColor;
      if (item.color != null) {
        try {
          sliceColor = Color(
            int.parse(item.color!.substring(1, 7), radix: 16) + 0xFF000000,
          );
        } catch (_) {
          sliceColor = _sliceColors[colorIndex % _sliceColors.length];
        }
      } else {
        sliceColor = _sliceColors[colorIndex % _sliceColors.length];
        colorIndex++;
      }

      // 슬라이스
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.78),
        startAngle,
        sweepAngle,
        true,
        Paint()..color = sliceColor.withValues(alpha: 0.75),
      );

      // 슬라이스 테두리
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.78),
        startAngle,
        sweepAngle,
        true,
        Paint()
          ..color = const Color(0xFF12082A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // 아이템 제목
      if (sweepAngle > 0.18) {
        final midAngle = startAngle + sweepAngle / 2;
        final textRadius = radius * 0.50;
        final tx = center.dx + textRadius * cos(midAngle);
        final ty = center.dy + textRadius * sin(midAngle);

        final textPainter = TextPainter(
          text: TextSpan(
            text: item.title,
            style: GoogleFonts.notoSans(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLines: 2,
        )..layout(maxWidth: radius * 0.5);

        textPainter.paint(
          canvas,
          Offset(tx - textPainter.width / 2, ty - textPainter.height / 2),
        );
      }
    }

    // ── 눈금 및 시간 숫자 ──
    for (int i = 0; i < 24; i++) {
      final angle = (i / 24) * 2 * pi - pi / 2;
      final isMajor = i % 6 == 0;
      final isMinor6 = i % 3 == 0;

      final innerRadius = isMajor
          ? radius * 0.86
          : isMinor6
              ? radius * 0.90
              : radius * 0.93;
      final tickColor = isMajor
          ? Colors.white.withValues(alpha: 0.5)
          : Colors.white.withValues(alpha: 0.2);

      canvas.drawLine(
        Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle)),
        Offset(
          center.dx + innerRadius * cos(angle),
          center.dy + innerRadius * sin(angle),
        ),
        Paint()
          ..color = tickColor
          ..strokeWidth = isMajor ? 1.5 : 0.8,
      );

      if (i % 6 == 0) {
        final textRadius = radius + 14;
        final tx = center.dx + textRadius * cos(angle);
        final ty = center.dy + textRadius * sin(angle);

        final tp = TextPainter(
          text: TextSpan(
            text: '$i',
            style: GoogleFonts.notoSans(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(tx - tp.width / 2, ty - tp.height / 2),
        );
      }
    }

    // ── 테두리 ──
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF6C63FF).withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // ── 중심 점 ──
    final centerGlow = Paint()
      ..color = const Color(0xFF6C63FF).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, 8, centerGlow);
    canvas.drawCircle(
      center,
      5,
      Paint()..color = const Color(0xFF9D8FFF),
    );
    canvas.drawCircle(
      center,
      2,
      Paint()..color = Colors.white,
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
