import 'package:flutter_test/flutter_test.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/data/category_data.dart';

void main() {
  group('Store Rating Calculation', () {
    test('Calculates average rating correctly from reviews list', () {
      final store = Store.fromMap({
        'id': 'test-id',
        'name': 'Test Cafe',
        'folder_name': 'test_folder',
        'reviews': [
          {'drink': 5.0, 'hygiene': 4.0, 'atmosphere': 5.0, 'final': 4.5},
          {'drink': 4.0, 'hygiene': 3.0, 'atmosphere': 4.0, 'final': 3.5},
        ]
      });

      expect(store.rating, closeTo(4.1666, 0.001));
      expect(store.reviews?.length, equals(2));
    });

    test('Handles empty reviews by falling back to rating column', () {
      final store = Store.fromMap({
        'id': 'test-id',
        'name': 'Test Cafe',
        'folder_name': 'test_folder',
        'rating': 4.2,
        'reviews': []
      });

      expect(store.rating, equals(4.2));
    });

    test('Handles missing reviews by falling back to rating column', () {
      final store = Store.fromMap({
        'id': 'test-id',
        'name': 'Test Cafe',
        'folder_name': 'test_folder',
        'rating': 3.8
      });

      expect(store.rating, equals(3.8));
    });

    test('copyWith updates fields correctly', () {
      final store = Store(
        id: '1',
        name: 'Old Name',
        rating: 3.0,
      );

      final updatedStore = store.copyWith(
        name: 'New Name',
        reviews: [{'final': 5.0}]
      );

      expect(updatedStore.id, equals('1'));
      expect(updatedStore.name, equals('New Name'));
      // Note that in plain constructor call we do not recalculate rating,
      // but the copyWith assigns the properties directly.
      expect(updatedStore.reviews?.length, equals(1));
    });

    test('getStoreCategories splits slash-separated labels and matches correctly', () {
      final store1 = Store(
        name: 'Europe Cafe',
        categoryTags: ['유럽'],
      );
      final store2 = Store(
        name: 'Quiet Cafe',
        categoryTags: ['카공'],
      );
      final store3 = Store(
        name: 'Other Cafe',
        categoryTags: ['힙'],
      );

      final cats1 = getStoreCategories(store1);
      final cats2 = getStoreCategories(store2);
      final cats3 = getStoreCategories(store3);

      expect(cats1.map((c) => c.label), contains('유럽/정원'));
      expect(cats2.map((c) => c.label), contains('조용한/카공'));
      expect(cats3.map((c) => c.label), contains('힙/인테리어'));
    });
  });
}
