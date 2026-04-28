import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';

class SelectedCategoriesNotifier extends StateNotifier<Set<Category>> {
  SelectedCategoriesNotifier() : super({});

  void toggle(Category category) {
    final updated = Set<Category>.from(state);
    if (updated.contains(category)) {
      updated.remove(category);
    } else {
      updated.add(category);
    }
    state = updated;
  }

  void remove(Category category) {
    final updated = Set<Category>.from(state);
    updated.remove(category);
    state = updated;
  }

  void clear() {
    state = {};
  }

  /// OR filtering – true if item matches ANY selected category.
  bool matchesAny(List<Category> itemCategories) {
    if (state.isEmpty) return true;
    return state.any((selected) => itemCategories.contains(selected));
  }

  /// AND filtering – true if item matches ALL selected categories.
  bool matchesAll(List<Category> itemCategories) {
    if (state.isEmpty) return true;
    return state.every((selected) => itemCategories.contains(selected));
  }
}

final selectedCategoriesProvider =
    StateNotifierProvider<SelectedCategoriesNotifier, Set<Category>>(
  (ref) => SelectedCategoriesNotifier(),
);
