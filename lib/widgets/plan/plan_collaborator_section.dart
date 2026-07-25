import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/plan.dart';

/// 일정의 공동 작업자 멤버 목록을 표시하는 위젯.
class PlanCollaboratorSection extends StatelessWidget {
  final PlanDetail detail;
  final Function(PlanCollaborator) onRemoveCollaborator;

  const PlanCollaboratorSection({
    super.key,
    required this.detail,
    required this.onRemoveCollaborator,
  });

  @override
  Widget build(BuildContext context) {
    if (detail.collaborators.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: detail.collaborators.map((member) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8E1D9)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                  child: Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                    style: GoogleFonts.notoSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: const Color(0xFF6C63FF),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            member.name,
                            style: GoogleFonts.notoSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          if (member.isSelf) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '나',
                                style: GoogleFonts.notoSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF6C63FF),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.email,
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                if (detail.plan.isOwner && !member.isSelf)
                  IconButton(
                    onPressed: () => onRemoveCollaborator(member),
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                    color: const Color(0xFFDC2626),
                    tooltip: '내보내기',
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E1D9)),
      ),
      child: Column(
        children: [
          const Icon(Icons.group_outlined, color: Color(0xFFB3B9C4)),
          const SizedBox(height: 8),
          Text(
            '아직 함께하는 공동 작업자가 없어요.',
            style: GoogleFonts.notoSans(
              fontSize: 13,
              color: const Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
