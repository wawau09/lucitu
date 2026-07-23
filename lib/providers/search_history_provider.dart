import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super([]) {
    _loadHistory();
  }

  static const String _key = 'recent_search_history';

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_key) ?? [];
      state = history;
    } catch (_) {}
  }

  Future<void> addQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final newList = [trimmed, ...state.where((q) => q != trimmed)].take(10).toList();
    state = newList;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, newList);
    } catch (_) {}
  }

  Future<void> removeQuery(String query) async {
    final newList = state.where((q) => q != query).toList();
    state = newList;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, newList);
    } catch (_) {}
  }

  Future<void> clearAll() async {
    state = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});
