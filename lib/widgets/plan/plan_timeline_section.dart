import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/plan.dart';

/// 일정의 06시~24시 수평 타임라인 리스트 뷰 위젯.
class PlanTimelineSection extends StatelessWidget {
  final PlanDetail detail;
  final Function(TimeOfDay time) onTimeTap;
  final Function(PlanItem item) onItemTap;

  const PlanTimelineSection({
    super.key,
    required this.detail,
    required this.onTimeTap,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final hours = List.generate(19, (index) => index + 6); // 06:00 ~ 24:00

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: hours.map((hour) {
        final timeString = '${hour.toString().padLeft(2, '0')}:00';

        final itemsInHour = detail.items.where((item) {
          if (item.startTime == null || item.startTime!.isEmpty) return false;
          final parts = item.startTime!.split(':');
          if (parts.isNotEmpty) {
            final itemHour = int.tryParse(parts[0]);
            return itemHour == hour;
          }
          return false;
        }).toList();

        return InkWell(
          onTap: () => onTimeTap(TimeOfDay(hour: hour, minute: 0)),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    timeString,
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: itemsInHour.isEmpty
                      ? Container(
                          height: 32,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: const Color(0xFFE5E7EB),
                                width: 0.8,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: itemsInHour.map((item) {
                            return GestureDetector(
                              onTap: () => onItemTap(item),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: Color(0xFF6C63FF),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      item.title,
                                      style: GoogleFonts.notoSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
