import 'package:placelist/DB/store.dart';

class MapStoreItem {
  final Store store;
  final double displayLat;
  final double displayLng;
  final int clusterIndex; // 0-based index in location cluster
  final int clusterTotal; // total stores in location cluster
  final List<Store> clusterStores; // all stores sharing this location

  MapStoreItem({
    required this.store,
    required this.displayLat,
    required this.displayLng,
    required this.clusterIndex,
    required this.clusterTotal,
    required this.clusterStores,
  });
}

/// Group valid stores sharing similar coordinates into clusters.
/// Returns exactly ONE MapStoreItem per unique location cluster.
List<MapStoreItem> groupStoresByLocation(
  List<Store> stores, {
  double threshold = 0.00008,
  String? selectedStoreId,
}) {
  final validStores = stores.where((s) => s.latitude != null && s.longitude != null).toList();
  final List<List<Store>> clusters = [];

  for (final store in validStores) {
    bool added = false;
    for (final cluster in clusters) {
      final base = cluster.first;
      if ((store.latitude! - base.latitude!).abs() < threshold &&
          (store.longitude! - base.longitude!).abs() < threshold) {
        cluster.add(store);
        added = true;
        break;
      }
    }
    if (!added) {
      clusters.add([store]);
    }
  }

  final List<MapStoreItem> result = [];

  for (final cluster in clusters) {
    final int total = cluster.length;
    // Find index of selected store if in this cluster, else default to 0
    int activeIndex = 0;
    if (selectedStoreId != null) {
      final idx = cluster.indexWhere((s) => s.id == selectedStoreId);
      if (idx >= 0) activeIndex = idx;
    }

    final activeStore = cluster[activeIndex];
    final baseLat = cluster.first.latitude!;
    final baseLng = cluster.first.longitude!;

    result.add(
      MapStoreItem(
        store: activeStore,
        displayLat: baseLat,
        displayLng: baseLng,
        clusterIndex: activeIndex,
        clusterTotal: total,
        clusterStores: cluster,
      ),
    );
  }

  return result;
}
