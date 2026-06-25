import '../models/category_model.dart';
import '../DB/store.dart';

const List<Category> allCategories = [
  Category(id: 'bakery',      label: '베이커리',     group: 'Style'),
  Category(id: 'coffee',      label: '커피전문',     group: 'Style'),
  Category(id: 'europe',      label: '유럽/정원',    group: 'Style'),
  Category(id: 'quiet',       label: '조용한/카공',  group: 'Vibe'),
  Category(id: 'hip',         label: '힙/인테리어',  group: 'Vibe'),
  Category(id: 'pet',         label: '애견동반',     group: 'Vibe'),
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
      final normalizedTag = tag.toLowerCase().trim();
      try {
        // id 매칭 (영문 id: 'coffee', 'jeonpo' 등)
        final cat = allCategories.firstWhere(
          (c) =>
              c.id == normalizedTag ||
              c.label == tag.trim(), // label 매칭 (한글: '커피', '전포' 등)
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

  // 베이커리
  if (name.contains('베이커리') || name.contains('빵') || name.contains('베이글') ||
      name.contains('도넛') || name.contains('케이크') || name.contains('타르트') ||
      name.contains('쿠키') || name.contains('파이')) {
    addCat('bakery');
  }

  // 커피전문
  if (name.contains('커피') || name.contains('로스터') || name.contains('에스프레소') ||
      name.contains('브루') || name.contains('드립')) {
    addCat('coffee');
  }

  // 유럽/정원
  if (name.contains('유럽') || name.contains('프랑스') || name.contains('정원') ||
      name.contains('가든') || name.contains('식물') || name.contains('빈티지')) {
    addCat('europe');
  }

  // 조용한/카공
  if (name.contains('조용') || name.contains('공부') || name.contains('스터디') ||
      name.contains('카공') || name.contains('독서')) {
    addCat('quiet');
  }

  // 힙/인테리어
  if (name.contains('힙') || name.contains('인테리어') || name.contains('무드') ||
      name.contains('감성') || name.contains('포토')) {
    addCat('hip');
  }

  // 애견동반
  if (name.contains('애견') || name.contains('반려') || name.contains('펫') ||
      name.contains('dog') || name.contains('pet')) {
    addCat('pet');
  }

  return categories;
}
