import 'package:flutter_test/flutter_test.dart';
import 'package:placelist/DB/store.dart';

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

      expect(store.rating, equals(4.0)); // (4.5 + 3.5) / 2 = 4.0
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
        folderName: 'folder',
        rating: 3.0,
      );

      final updatedStore = store.copyWith(
        name: 'New Name',
        reviews: [{'final': 5.0}]
      );

      expect(updatedStore.id, equals('1'));
      expect(updatedStore.name, equals('New Name'));
      expect(updatedStore.folderName, equals('folder'));
      // Note that in plain constructor call we do not recalculate rating,
      // but the copyWith assigns the properties directly.
      expect(updatedStore.reviews?.length, equals(1));
    });
  });
}
