import 'package:flutter/material.dart';
import '../data/category_data.dart';
import 'category_chip.dart';

/// Category filter section with a single horizontally scrollable row.
class CategoryFilterSection extends StatelessWidget {
  const CategoryFilterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
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
