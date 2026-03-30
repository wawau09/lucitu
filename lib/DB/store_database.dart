import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:placelist/DB/store.dart';

class StoreDatabase {
  final CollectionReference _storesCollection = 
      FirebaseFirestore.instance.collection('stores');

  // Create
  Future<void> createStore(Store newStore) async {
    await _storesCollection.add(newStore.toMap());
  }

  // Read (Stream)
  // Firestore 컬렉션의 변화를 실시간으로 감지하여 List<Store>로 변환
  Stream<List<Store>> get stream {
    return _storesCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Store.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // Update
  Future<void> updateStore(Store oldStore, String newName) async {
    await _storesCollection.doc(oldStore.id).update({
      'name': newName
    });
  }

  // Delete
  Future<void> deleteStore(Store store) async {
    await _storesCollection.doc(store.id).delete();
  }
}