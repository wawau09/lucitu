import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../data/category_data.dart';
import 'category_chip.dart';
import 'selected_filter_bar.dart';
import '../providers/category_provider.dart';

/// Category filter section with a single horizontally scrollable row.
class CategoryFilterSection extends ConsumerWidget {
  const CategoryFilterSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Only show filter bar and its spacing if categories are selected
        if (selected.isNotEmpty) ...[
          const SelectedFilterBar(),
          const SizedBox(height: 8),
        ],

        // Single horizontally scrollable row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children:
                allCategories
                    .map(
                      (cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: CategoryChip(category: cat),
                      ),
                    )
                    .toList(),
          ),
        ),
      ],
    );
  }
}
