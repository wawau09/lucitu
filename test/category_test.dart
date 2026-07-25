import 'package:flutter_test/flutter_test.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/data/category_data.dart';

void main() {
  group('Category Data Tests', () {
    test('getStoreCategories matches bakery tag correctly', () {
      final store = Store(
        name: '성수 빵집',
        categoryTags: ['bakery'],
      );

      final categories = getStoreCategories(store);
      expect(categories, isNotEmpty);
      expect(categories.any((c) => c.id == 'bakery'), isTrue);
    });

    test('getStoreCategories falls back to name matching when tags are empty', () {
      final store = Store(
        name: '조용한 분위기 스터디 카페',
        categoryTags: [],
      );

      final categories = getStoreCategories(store);
      expect(categories, isNotEmpty);
      expect(categories.any((c) => c.id == 'quiet'), isTrue);
    });

    test('getStoreCategories returns cached result on second call', () {
      final store = Store(
        name: '테라스 애견동반 카페',
        categoryTags: ['terrace', 'pet'],
      );

      final categories1 = getStoreCategories(store);
      final categories2 = getStoreCategories(store);

      expect(identical(categories1, categories2), isTrue);
    });
  });
}
