import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/store.dart';

/// 커스텀 마커 오버레이 이미지를 빌드하고 [NMarker]를 반환하는 헬퍼 함수.
///
/// [context]    - 위젯 빌드에 사용할 BuildContext
/// [store]      - 마커에 표시할 가게 정보
/// [isSelected] - 현재 선택된 마커 여부 (크기·색상 강조)
/// [isDark]     - 다크모드 여부
Future<NMarker> buildCustomMarker({
  required BuildContext context,
  required Store store,
  bool isSelected = false,
  bool isDark = false,
}) async {
  final overlayImage = await NOverlayImage.fromWidget(
    widget: _MarkerWidget(store: store, isSelected: isSelected, isDark: isDark),
    size: isSelected ? const Size(100, 60) : const Size(86, 50),
    context: context,
  );

  final marker = NMarker(
    id: store.id ?? store.name,
    position: NLatLng(store.latitude!, store.longitude!),
    icon: overlayImage,
    size: isSelected ? const Size(100, 60) : const Size(86, 50),
    anchor: const NPoint(0.5, 1.0),
  );
  marker.setZIndex(isSelected ? 10 : 1);

  return marker;
}

// ─────────────────────────────────────────────
// 마커 위젯
// ─────────────────────────────────────────────

class _MarkerWidget extends StatelessWidget {
  final Store store;
  final bool isSelected;
  final bool isDark;

  const _MarkerWidget({
    required this.store,
    this.isSelected = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? const Color(0xFF6C63FF) // 선택 시 보라계열 강조
        : (isDark ? const Color(0xFF1C1C1E) : Colors.white);

    final textColor = isSelected
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF1C1C1E));

    final iconColor = isSelected ? Colors.white : const Color(0xFF6C63FF);
    final borderColor = isSelected ? const Color(0xFF8A84FF) : const Color(0xFF6C63FF);
    final shadowColor = isSelected
        ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.18);

    final rating = store.rating;
    final ratingText = rating != null && rating > 0
        ? rating.toStringAsFixed(1)
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 말풍선 본체 ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: isSelected ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_cafe_rounded, size: 13, color: iconColor),
              const SizedBox(width: 4),
              Text(
                store.name,
                style: GoogleFonts.notoSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
              ),
              if (ratingText != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : const Color(0xFF6C63FF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 9,
                        color: isSelected ? Colors.amber[200] : Colors.amber,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        ratingText,
                        style: GoogleFonts.notoSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF6C63FF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── 아래 꼬리 (drop shadow 포함) ──
        CustomPaint(
          size: const Size(12, 7),
          painter: _MarkerTailPainter(
            color: isSelected ? const Color(0xFF6C63FF) : bg,
            borderColor: borderColor,
          ),
        ),
      ],
    );
  }
}

// 말풍선 꼬리 painter
class _MarkerTailPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _MarkerTailPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // border 삼각형
    final borderPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(borderPath, borderPaint);

    // fill 삼각형 (1px 작게)
    final fillPath = Path()
      ..moveTo(1.2, 0)
      ..lineTo(size.width / 2, size.height - 1.5)
      ..lineTo(size.width - 1.2, 0)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _MarkerTailPainter old) =>
      old.color != color || old.borderColor != borderColor;
}
