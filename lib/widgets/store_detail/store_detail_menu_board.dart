import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/utils/app_colors.dart';

class StoreDetailMenuBoard extends StatelessWidget {
  final Map<String, dynamic> menu;
  final bool isDark;

  const StoreDetailMenuBoard({
    super.key,
    required this.menu,
    required this.isDark,
  });

  String _formatMenuValue(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      final str = value.toInt().toString();
      final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      final formatted = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
      return '$formatted원';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.restaurant_menu,
              color: isDark ? AppColors.accentLight : AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              "메뉴판",
              style: GoogleFonts.notoSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: menu.entries.map((entry) {
              final isLast = menu.entries.last.key == entry.key;
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: GoogleFonts.notoSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        _formatMenuValue(entry.value),
                        style: GoogleFonts.notoSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.accentLight : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (!isLast) ...[
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEEEEEE),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
