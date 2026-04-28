import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../providers/category_provider.dart';

class CategoryChip extends ConsumerWidget {
  final Category category;

  const CategoryChip({super.key, required this.category});

  static const _selectedColor = Color(0xFF2E7D32); // dark green

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected =
        ref.watch(selectedCategoriesProvider).contains(category);

    return GestureDetector(
      onTap: () =>
          ref.read(selectedCategoriesProvider.notifier).toggle(category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? _selectedColor : Colors.grey.shade400,
            width: 1.2,
          ),
        ),
        child: Text(
          category.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
