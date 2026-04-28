import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../data/category_data.dart';
import 'category_chip.dart';
import 'selected_filter_bar.dart';
import '../providers/category_provider.dart';

/// Category filter section with 2 horizontally scrollable rows.
class CategoryFilterSection extends ConsumerWidget {
  const CategoryFilterSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoriesProvider);

    // Split categories into two rows
    final topRow = <Category>[];
    final bottomRow = <Category>[];
    
    for (int i = 0; i < allCategories.length; i++) {
      if (i % 2 == 0) {
        topRow.add(allCategories[i]);
      } else {
        bottomRow.add(allCategories[i]);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Only show filter bar and its spacing if categories are selected
        if (selected.isNotEmpty) ...[
          const SelectedFilterBar(),
          const SizedBox(height: 8),
        ],
        
        // 2 horizontally scrollable rows
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: topRow.map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: CategoryChip(category: cat),
                )).toList(),
              ),
              Row(
                children: bottomRow.map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CategoryChip(category: cat),
                )).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
