import 'package:placelist/DB/store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoreDatabase {
  final SupabaseClient _client = Supabase.instance.client;
  final String _table = 'cafes';

  Future<void> createStore(Store newStore) async {
    await _client.from(_table).insert(newStore.toMap());
  }

  Stream<List<Store>> get stream {
    return _client.from(_table).stream(primaryKey: ['id']).map((rows) {
      return rows.map((row) => Store.fromMap(row)).toList();
    });
  }

  Future<List<Store>> getStores() async {
    final List<dynamic> rows = await _client
        .from(_table)
        .select('id, name, latitude, longitude, category_tags, image_urls, region')
        .order('id');

    final storesById = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['id']?.toString();
      if (id != null) {
        map['reviews'] = <dynamic>[];
        storesById[id] = map;
      }
    }

    try {
      final List<dynamic> reviewRows = await _client
          .from('store_reviews')
          .select(
              'store_id, user_id, drink, hygiene, atmosphere, final_score, created_at')
          .order('created_at');

      for (final row in reviewRows) {
        final review = Map<String, dynamic>.from(row as Map);
        final storeId = review['store_id']?.toString();
        final store = storesById[storeId];
        if (store == null) continue;

        (store['reviews'] as List<dynamic>).add({
          'user_id': review['user_id'],
          'drink': review['drink'],
          'hygiene': review['hygiene'],
          'atmosphere': review['atmosphere'],
          'final': review['final_score'],
          'created_at': review['created_at'],
        });
      }
    } catch (e) {
      // The rating table may not exist until the Supabase SQL is applied.
    }

    return storesById.values.map(Store.fromMap).toList();
  }

  Future<void> updateStore(Store oldStore, String newName) async {
    if (oldStore.id == null) return;
    await _client.from(_table).update({'name': newName}).eq('id', oldStore.id!);
  }

  Future<void> deleteStore(Store store) async {
    if (store.id == null) return;
    await _client.from(_table).delete().eq('id', store.id!);
  }
}
