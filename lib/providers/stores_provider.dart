import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../DB/store.dart';
import '../DB/store_database.dart';

class StoresNotifier extends StateNotifier<AsyncValue<List<Store>>> {
  StoresNotifier() : super(const AsyncValue.loading()) {
    fetchStores();
  }

  final StoreDatabase _db = StoreDatabase();
  final SupabaseClient _client = Supabase.instance.client;

  bool hasUserRatedStore(String storeId, String userId) {
    final stores = state.valueOrNull;
    if (stores == null) return false;

    try {
      final store = stores.firstWhere((s) => s.id == storeId);
      return _hasUserReview(store.reviews, userId);
    } catch (_) {
      return false;
    }
  }

  Future<void> fetchStores() async {
    state = const AsyncValue.loading();
    try {
      final dbStores = await _db.getStores();
      final prefs = await SharedPreferences.getInstance();

      final List<Store> mergedStores = [];
      for (var store in dbStores) {
        if (store.id == null) {
          mergedStores.add(store);
          continue;
        }

        final key = 'local_reviews_${store.id}';
        final localJsonList = prefs.getStringList(key) ?? [];
        final List<dynamic> localReviews = localJsonList
            .map((str) => jsonDecode(str))
            .toList();

        // Deduplicate using created_at as key
        final Map<String, Map<String, dynamic>> allReviewsMap = {};

        if (store.reviews != null) {
          for (var rev in store.reviews!) {
            if (rev is Map) {
              final keyStr = rev['created_at']?.toString() ?? rev.hashCode.toString();
              allReviewsMap[keyStr] = Map<String, dynamic>.from(rev);
            }
          }
        }

        for (var rev in localReviews) {
          if (rev is Map) {
            final keyStr = rev['created_at']?.toString() ?? rev.hashCode.toString();
            allReviewsMap[keyStr] = Map<String, dynamic>.from(rev);
          }
        }

        final mergedList = allReviewsMap.values.toList();

        // Sort reviews by created_at ascending
        mergedList.sort((a, b) {
          final timeA = a['created_at']?.toString() ?? '';
          final timeB = b['created_at']?.toString() ?? '';
          return timeA.compareTo(timeB);
        });

        // Reconstruct the store to recalculate rating
        final storeMap = store.toMap()..['reviews'] = mergedList;
        mergedStores.add(Store.fromMap(storeMap..['id'] = store.id));
      }

      state = AsyncValue.data(mergedStores);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> submitRating({
    required String storeId,
    required double drink,
    required double hygiene,
    required double atmosphere,
    required double finalScore,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const RatingSubmissionException('loginRequired');
    }

    final userId = user.id;

    // Find the current store reviews in state
    List<dynamic> currentReviews = [];
    state.whenData((stores) {
      try {
        final store = stores.firstWhere((s) => s.id == storeId);
        currentReviews = store.reviews ?? [];
      } catch (_) {}
    });

    if (_hasUserReview(currentReviews, userId)) {
      throw const RatingSubmissionException('alreadyRated');
    }

    final newReview = {
      'user_id': userId,
      'drink': drink,
      'hygiene': hygiene,
      'atmosphere': atmosphere,
      'final': finalScore,
      'created_at': DateTime.now().toIso8601String(),
    };

    final updatedReviews = List<dynamic>.from(currentReviews)..add(newReview);

    // 1. Update SharedPreferences first for instant and reliable local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'local_reviews_$storeId';
      final localJsonList = prefs.getStringList(key) ?? [];
      localJsonList.add(jsonEncode(newReview));
      await prefs.setStringList(key, localJsonList);
    } catch (e) {
      print('Failed to save review locally: $e');
    }

    // 2. Try to update Supabase
    try {
      await _client
          .from('stores')
          .update({'reviews': updatedReviews})
          .eq('id', storeId);
    } catch (e) {
      print('Failed to update Supabase reviews: $e (This is expected if RLS is enabled)');
    }

    // 3. Refresh state locally to avoid needing a full network fetch
    state.whenData((stores) {
      final updatedStores = stores.map((store) {
        if (store.id == storeId) {
          final storeMap = store.toMap()..['reviews'] = updatedReviews;
          return Store.fromMap(storeMap..['id'] = storeId);
        }
        return store;
      }).toList();
      state = AsyncValue.data(updatedStores);
    });
  }

  bool _hasUserReview(List<dynamic>? reviews, String userId) {
    if (reviews == null) return false;

    return reviews.any((review) {
      if (review is! Map) return false;
      final reviewUserId = review['user_id'] ?? review['userId'];
      return reviewUserId?.toString() == userId;
    });
  }
}

class RatingSubmissionException implements Exception {
  final String code;

  const RatingSubmissionException(this.code);
}

final storesProvider =
    StateNotifierProvider<StoresNotifier, AsyncValue<List<Store>>>((ref) {
  return StoresNotifier();
});
