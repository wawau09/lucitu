import 'package:placelist/DB/store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoreDatabase {
  final SupabaseClient _client = Supabase.instance.client;
  final String _table = 'stores';

  Future<void> createStore(Store newStore) async {
    await _client.from(_table).insert(newStore.toMap());
  }

  Stream<List<Store>> get stream {
    return _client.from(_table).stream(primaryKey: ['id']).map((rows) {
      return rows.map((row) => Store.fromMap(row)).toList();
    });
  }

  Future<List<Store>> getStores() async {
    final List<dynamic> rows = await _client.from(_table).select().order('id');
    return rows.map((row) => Store.fromMap(row as Map<String, dynamic>)).toList();
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