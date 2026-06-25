import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../DB/store.dart';
import 'stores_provider.dart';

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier();
});

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super({}) {
    _init();
  }

  final _supabase = Supabase.instance.client;

  void _init() {
    // 사용자가 바뀔 때마다 찜 목록을 다시 불러옵니다.
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session?.user != null) {
        fetchFavorites();
      } else {
        state = {};
      }
    });
    
    // 현재 세션이 있으면 즉시 로드
    if (_supabase.auth.currentUser != null) {
      fetchFavorites();
    }
  }

  Future<void> fetchFavorites() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final List<dynamic> data = await _supabase
          .from('favorites')
          .select('store_id')
          .eq('user_id', user.id);

      state = data.map((item) => item['store_id'].toString()).toSet();
    } catch (e) {
      print('찜 목록 로드 실패: $e');
    }
  }

  Future<void> toggleFavorite(String storeId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final isFavorited = state.contains(storeId);

    // Optimistic UI: 먼저 상태를 즉시 변경
    if (isFavorited) {
      state = {...state}..remove(storeId);
    } else {
      state = {...state, storeId};
    }

    try {
      if (isFavorited) {
        // DB에서 제거
        await _supabase
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('store_id', storeId);
      } else {
        // DB에 추가 (upsert로 중복 삽입 오류 방지)
        await _supabase.from('favorites').upsert(
          {
            'user_id': user.id,
            'store_id': storeId,
          },
          onConflict: 'user_id,store_id',
        );
      }
    } catch (e) {
      // DB 실패 시 optimistic update 롤백
      if (isFavorited) {
        state = {...state, storeId};
      } else {
        state = {...state}..remove(storeId);
      }
      print('찜 토글 실패: $e');
      rethrow; // UI에서 에러 처리 가능하도록 rethrow
    }
  }

  bool isFavorited(String storeId) => state.contains(storeId);
}

// 찜한 스토어 객체 목록을 가져오는 프로바이더 (추가 기능용)
final favoritedStoresProvider = Provider<AsyncValue<List<Store>>>((ref) {
  final favoriteIds = ref.watch(favoritesProvider);
  final storesAsync = ref.watch(storesProvider);

  return storesAsync.when(
    data: (stores) {
      final favorited = stores
          .where((store) => store.id != null && favoriteIds.contains(store.id))
          .toList();
      return AsyncValue.data(favorited);
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});
