import 'package:flutter_test/flutter_test.dart';
import 'package:placelist/providers/search_history_provider.dart';

void main() {
  group('Search History Notifier Tests', () {
    test('addQuery adds query and avoids duplicates', () {
      final notifier = SearchHistoryNotifier();
      notifier.addQuery('강남 카페');
      expect(notifier.state.contains('강남 카페'), isTrue);

      notifier.addQuery('강남 카페');
      final count = notifier.state.where((e) => e == '강남 카페').length;
      expect(count, equals(1));
    });

    test('removeQuery removes specified query', () {
      final notifier = SearchHistoryNotifier();
      notifier.addQuery('성수 디저트');
      expect(notifier.state.contains('성수 디저트'), isTrue);

      notifier.removeQuery('성수 디저트');
      expect(notifier.state.contains('성수 디저트'), isFalse);
    });

    test('clearAll empties state', () {
      final notifier = SearchHistoryNotifier();
      notifier.addQuery('홍대 카페');
      notifier.addQuery('연남 맛집');
      expect(notifier.state, isNotEmpty);

      notifier.clearAll();
      expect(notifier.state, isEmpty);
    });
  });
}
