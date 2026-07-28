import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/plan.dart';

class PlanCardItem extends StatelessWidget {
  final PlanSummary plan;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const PlanCardItem({
    super.key,
    required this.plan,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildPill({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 100,
                height: 100,
                color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[100],
                child: Icon(
                  Icons.event_note,
                  size: 40,
                  color: isDark ? Colors.white24 : Colors.grey[400],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan.name,
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (plan.sharedWithMe)
                          _buildPill(
                            label: '공유중',
                            background: isDark
                                ? const Color(0xFF1E3A5F)
                                : const Color(0xFFF0F6FF),
                            foreground: isDark
                                ? const Color(0xFF82B1FF)
                                : const Color(0xFF2F5E8F),
                          )
                        else
                          _buildPill(
                            label: '내 일정',
                            background: isDark
                                ? const Color(0xFF2D3748)
                                : const Color(0xFFF5F7FB),
                            foreground: isDark
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF374151),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: isDark ? Colors.white38 : Colors.grey[600],
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatDate(plan.planDate),
                            style: GoogleFonts.notoSans(
                              fontSize: 14,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          '코드: ${plan.planCode}',
                          style: GoogleFonts.notoSans(
                            fontSize: 12,
                            color: isDark ? Colors.white30 : Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (plan.isOwner)
                          IconButton(
                            onPressed: onDelete,
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        else
                          const SizedBox(height: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
