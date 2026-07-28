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

/// Group valid stores sharing similar coordinates and calculate vertical offsets
/// so overlapping markers stack neatly upwards on the map view.
List<MapStoreItem> groupStoresByLocation(List<Store> stores, {double threshold = 0.00008}) {
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
    for (int i = 0; i < total; i++) {
      final store = cluster[i];
      // Index 0 stays at base location.
      // Index > 0 shifts upwards in latitude with a tiny horizontal stagger for visual clarity.
      final double latOffset = i * 0.00016;
      final double lngOffset = (total > 1 && i > 0) ? (i % 2 == 1 ? 0.00002 : -0.00002) : 0.0;

      result.add(
        MapStoreItem(
          store: store,
          displayLat: store.latitude! + latOffset,
          displayLng: store.longitude! + lngOffset,
          clusterIndex: i,
          clusterTotal: total,
          clusterStores: cluster,
        ),
      );
    }
  }

  return result;
}
