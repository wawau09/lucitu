import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      state = AsyncValue.data(dbStores);
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
    String? comment,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const RatingSubmissionException('loginRequired');
    }

    final List<dynamic> updatedReviews;
    try {
      final result = await _client.rpc(
        'submit_store_rating',
        params: {
          'p_store_id': storeId,
          'p_drink': drink,
          'p_hygiene': hygiene,
          'p_atmosphere': atmosphere,
          'p_final': finalScore,
          if (comment != null && comment.trim().isNotEmpty)
            'p_comment': comment.trim(),
        },
      );

      if (result is! List) {
        throw const RatingSubmissionException('saveFailed');
      }

      updatedReviews = List<dynamic>.from(result);
    } catch (e) {
      if (e is RatingSubmissionException) rethrow;
      if (e is PostgrestException &&
          e.message.toLowerCase().contains('alreadyrated')) {
        throw const RatingSubmissionException('alreadyRated');
      }
      if (e is PostgrestException) {
        throw RatingSubmissionException('saveFailed', e.message);
      }
      throw RatingSubmissionException('saveFailed', e.toString());
    }

    // Refresh state after the DB write succeeds.
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
  final String? detail;

  const RatingSubmissionException(this.code, [this.detail]);
}

final storesProvider =
    StateNotifierProvider<StoresNotifier, AsyncValue<List<Store>>>((ref) {
  return StoresNotifier();
});
