import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/providers/plans_provider.dart';
import 'package:placelist/providers/stores_provider.dart';
import 'package:placelist/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  });
  group('StoresNotifier Logic Tests', () {
    test('hasUserRatedStore returns true if user review exists', () {
      final notifier = StoresNotifier();
      final storeWithReview = Store.fromMap({
        'id': 'store-100',
        'name': 'Sample Cafe',
        'folder_name': 'sample_folder',
        'reviews': [
          {'user_id': 'user-1', 'final': 4.5},
          {'user_id': 'user-2', 'final': 3.5},
        ],
      });

      // Manually set state for unit test
      notifier.state = AsyncValue.data([storeWithReview]);

      expect(notifier.hasUserRatedStore('store-100', 'user-1'), isTrue);
      expect(notifier.hasUserRatedStore('store-100', 'user-2'), isTrue);
      expect(notifier.hasUserRatedStore('store-100', 'user-999'), isFalse);
      expect(notifier.hasUserRatedStore('unknown-store', 'user-1'), isFalse);
    });

    test('RatingSubmissionException holds code and detail correctly', () {
      const ex1 = RatingSubmissionException('loginRequired');
      expect(ex1.code, equals('loginRequired'));
      expect(ex1.detail, isNull);

      const ex2 = RatingSubmissionException('saveFailed', 'DB Connection Timeout');
      expect(ex2.code, equals('saveFailed'));
      expect(ex2.detail, equals('DB Connection Timeout'));
    });
  });

  group('SelectedPlanIdProvider State Tests', () {
    test('selectedPlanIdProvider initial value is null and can be updated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedPlanIdProvider), isNull);

      container.read(selectedPlanIdProvider.notifier).state = 'plan-123';
      expect(container.read(selectedPlanIdProvider), equals('plan-123'));

      container.read(selectedPlanIdProvider.notifier).state = null;
      expect(container.read(selectedPlanIdProvider), isNull);
    });
  });
}
