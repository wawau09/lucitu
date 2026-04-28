import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/category_provider.dart';

class SelectedFilterBar extends ConsumerWidget {
  const SelectedFilterBar({super.key});

  static const _selectedColor = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoriesProvider);

    if (selected.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: selected.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = selected.elementAt(index);
          return Chip(
            label: Text(
              category.label,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            backgroundColor: _selectedColor,
            deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white),
            onDeleted: () => ref
                .read(selectedCategoriesProvider.notifier)
                .remove(category),
            shape: const StadiumBorder(),
            side: BorderSide.none,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}
