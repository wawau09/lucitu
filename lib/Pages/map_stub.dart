import 'package:flutter/material.dart';
import 'package:placelist/DB/store.dart';

Widget getWebMap(double lat, double lng, String name) {
  return const Center(child: Text('Web map not supported natively'));
}

Widget getWebMapStores(
  List<Store> stores, {
  String? selectedStoreId,
  void Function(String storeId)? onStoreSelected,
}) {
  return const Center(child: Text('Web map not supported natively'));
}

void selectWebMapMarker(String storeId) {}
