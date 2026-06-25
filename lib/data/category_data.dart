import '../models/category_model.dart';
import '../DB/store.dart';

const List<Category> allCategories = [
  Category(id: 'bakery',      label: '베이커리',     group: 'Style'),
  Category(id: 'quiet',       label: '조용한',       group: 'Vibe'),
  Category(id: 'terrace',     label: '테라스',       group: 'Vibe'),
  Category(id: 'view',        label: '뷰맛집',       group: 'Vibe'),
  Category(id: 'parking',     label: '주차가능',     group: 'Vibe'),
  Category(id: 'pet',         label: '애견동반',     group: 'Vibe'),
];

const Map<String, List<String>> categoryKeywords = {
  'bakery': ['베이커리', '빵', '베이글', '도넛', '케이크', '타르트', '쿠키', '파이', '디저트', 'bakery'],
  'quiet': ['조용', '조용한', '공부', '스터디', '카공', '독서'],
  'terrace': ['테라스', '루프탑', '야외', '정원', '가든', '테라스석'],
  'view': ['뷰', '전망', '오션뷰', '마운틴뷰', '경치', '뷰맛집', '바다뷰'],
  'parking': ['주차', '주차장', '주차가능'],
  'pet': ['애견', '애견동반', '반려동물', '반려', '펫', 'dog', 'pet'],
};

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
        final cat = allCategories.firstWhere(
          (c) {
            // 1. id 매칭 (영문 id)
            if (c.id == normalizedTag) return true;
            
            // 2. label 매칭 (한글)
            final labelText = c.label.trim();
            if (labelText == tag.trim()) return true;

            // 3. 키워드 매핑 매칭 (예: '카공' -> '조용한', '루프탑' -> '테라스')
            final keywords = categoryKeywords[c.id];
            if (keywords != null) {
              final cleanTag = tag.trim().toLowerCase();
              return keywords.any((kw) => kw.contains(cleanTag) || cleanTag.contains(kw));
            }

            return false;
          },
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
  final name = store.name.toLowerCase();

  for (final cat in allCategories) {
    final keywords = categoryKeywords[cat.id];
    if (keywords != null) {
      final matches = keywords.any((kw) => name.contains(kw));
      if (matches) {
        if (!categories.contains(cat)) {
          categories.add(cat);
        }
      }
    }
  }

  return categories;
}
