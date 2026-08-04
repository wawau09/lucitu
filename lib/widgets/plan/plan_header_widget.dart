import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PlanHeaderWidget extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRefresh;
  final VoidCallback onAddPlan;

  const PlanHeaderWidget({
    super.key,
    required this.isDark,
    required this.onRefresh,
    required this.onAddPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '내 일정',
            style: GoogleFonts.notoSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                onPressed: onRefresh,
              ),
              IconButton(
                icon: Icon(
                  Icons.add,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                onPressed: onAddPlan,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
