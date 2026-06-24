import '../models/category_model.dart';
import '../DB/store.dart';

const List<Category> allCategories = [
  // Area
  Category(id: 'jeonpo', label: '전포', group: 'Area'),
  Category(id: 'gwangalli', label: '광안리', group: 'Area'),
  Category(id: 'haeundae', label: '해운대', group: 'Area'),

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

/// Returns matched [Category] objects for a store based on its [category_tags] field.
/// Falls back to name-based heuristics if no tags are present.
List<Category> getStoreCategories(Store store) {
  // If the store has category_tags from the DB, use those directly
  if (store.categoryTags.isNotEmpty) {
    final categories = <Category>[];
    for (final tag in store.categoryTags) {
      try {
        final cat = allCategories.firstWhere(
          (c) => c.id == tag.toLowerCase().trim(),
        );
        if (!categories.contains(cat)) {
          categories.add(cat);
        }
      } catch (_) {
        // Tag not found in allCategories — skip
      }
    }
    return categories;
  }

  // Fallback: name-based heuristics (for data without tags)
  final categories = <Category>[];
  final name = store.name;

  Category? findCat(String id) {
    try {
      return allCategories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  void addCat(String id) {
    final cat = findCat(id);
    if (cat != null && !categories.contains(cat)) categories.add(cat);
  }

  // 1. Location / Area
  if (name.contains('전포')) addCat('jeonpo');
  if (name.contains('광안')) addCat('gwangalli');
  if (name.contains('해운대') || name.contains('해리단')) addCat('haeundae');

  // 2. Food/Drink
  if (name.contains('커피') || name.contains('카페') || name.contains('로스터리') || name.contains('에스프레소')) {
    addCat('coffee');
  }
  if (name.contains('주스') || name.contains('스무디') || name.contains('에이드') || name.contains('티')) {
    addCat('juice');
  }
  if (name.contains('디저트') || name.contains('베이글') || name.contains('쿠키') || name.contains('도넛') ||
      name.contains('케이크') || name.contains('베이커리') || name.contains('젤라또') || name.contains('타르트')) {
    addCat('dessert');
  }
  if (name.contains('브런치') || name.contains('샌드위치') || name.contains('바게트')) {
    addCat('brunch');
  }

  // 3. Concept/Style
  if (name.contains('유럽') || name.contains('프랑스')) addCat('europe');
  if (name.contains('빈티지')) addCat('vintage');
  if (name.contains('정원') || name.contains('가든') || name.contains('식물')) addCat('garden');

  // 4. View
  if (name.contains('오션') || name.contains('바다')) addCat('ocean');
  if (name.contains('마운틴') || name.contains('산')) addCat('mountain');
  if (name.contains('루프탑') || name.contains('테라스')) addCat('rooftop');

  // 5. Type
  if (name.contains('프랜차이즈') || name.contains('스타벅스') || name.contains('컴포즈') || name.contains('메가')) {
    addCat('franchise');
  } else {
    addCat('independent');
  }

  // 6. Purpose
  if (name.contains('가성비')) addCat('value');
  if (name.contains('혼카페') || name.contains('공부') || name.contains('스터디')) addCat('solo');

  return categories;
}
