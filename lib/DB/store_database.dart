import 'package:placelist/DB/store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoreDatabase {
  final database = Supabase.instance.client.from('stores');

  // Create
  Future createStore(Store newStore) async {
    await database.insert(newStore.toMap());
  }

  // Read
  final stream = Supabase.instance.client.from('stores').stream(
    primaryKey: ['id'],
  ).map((data) => data.map((storeMap) => Store.fromMap(storeMap)).toList());

  Future updateStore(Store oldStore, String newName) async {
    await database.update({
      'name': newName
    }).eq('id', oldStore.id!);
  }

  // Delete
  Future deleteStore(Store store) async {
    await database.delete().eq('id', store.id!);
  }
}