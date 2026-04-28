import '../models/category_model.dart';

const List<Category> allCategories = [
  // Food/Drink
  Category(id: 'coffee', label: '커피', group: 'Food/Drink'),
  Category(id: 'juice', label: '주스/스무디', group: 'Food/Drink'),
  Category(id: 'dessert', label: '디저트', group: 'Food/Drink'),
  Category(id: 'brunch', label: '브런치', group: 'Food/Drink'),

  // Concept/Style
  Category(id: 'europe', label: '유럽풍', group: 'Concept/Style'),
  Category(id: 'vintage', label: '빈티지', group: 'Concept/Style'),
  Category(id: 'garden', label: '정원', group: 'Concept/Style'),

  // View
  Category(id: 'ocean', label: '오션뷰', group: 'View'),
  Category(id: 'mountain', label: '마운틴뷰', group: 'View'),
  Category(id: 'rooftop', label: '루프탑', group: 'View'),

  // Type
  Category(id: 'franchise', label: '프랜차이즈', group: 'Type'),
  Category(id: 'independent', label: '개인', group: 'Type'),

  // Purpose
  Category(id: 'value', label: '가성비', group: 'Purpose'),
  Category(id: 'solo', label: '혼카페', group: 'Purpose'),
];

/// Groups categories by their group field.
Map<String, List<Category>> get categoriesByGroup {
  final map = <String, List<Category>>{};
  for (final cat in allCategories) {
    map.putIfAbsent(cat.group, () => []).add(cat);
  }
  return map;
}
