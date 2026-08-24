import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;
import 'package:placelist/DB/store.dart';

Widget getWebMap(double lat, double lng, String name) {
  final String viewType = 'naver-web-map-$lat-$lng';

  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final div =
        html.DivElement()
          ..id = 'naver-map-$viewId'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.touchAction = 'none';

    Future.delayed(const Duration(milliseconds: 200), () {
      js.context.callMethod('initNaverMap', [div, lat, lng, name]);
    });

    return div;
  });

  return RawGestureDetector(
    gestures: <Type, GestureRecognizerFactory>{
      EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
        () => EagerGestureRecognizer(),
        (EagerGestureRecognizer instance) {},
      ),
    },
    child: HtmlElementView(viewType: viewType),
  );
}

Widget getWebMapStores(
  List<Store> stores, {
  String? selectedStoreId,
  void Function(String storeId)? onStoreSelected,
}) {
  final validStores = stores.where((s) => s.latitude != null && s.longitude != null).toList();
  if (validStores.isEmpty) {
    return const Center(child: Text("지도에 표시할 위치 정보가 없습니다."));
  }

  if (onStoreSelected != null) {
    js.context['flutterOnSelectStore'] = (String storeId) {
      onStoreSelected(storeId);
    };
  }

  final clustersMap = <String, List<Map<String, dynamic>>>{};
  final clusterLocs = <String, Map<String, double>>{};

  for (final s in validStores) {
    String? matchedKey;
    for (final key in clusterLocs.keys) {
      final loc = clusterLocs[key]!;
      if ((s.latitude! - loc['lat']!).abs() < 0.00008 &&
          (s.longitude! - loc['lng']!).abs() < 0.00008) {
        matchedKey = key;
        break;
      }
    }
    final key = matchedKey ?? 'cluster_${s.id ?? s.name}';
    if (!clusterLocs.containsKey(key)) {
      clusterLocs[key] = {'lat': s.latitude!, 'lng': s.longitude!};
      clustersMap[key] = [];
    }
    clustersMap[key]!.add({
      'id': s.id ?? '',
      'name': s.name,
      'rating': s.rating ?? 0.0,
      'region': s.region ?? '',
    });
  }

  final clustersData = clustersMap.entries.map((e) {
    final loc = clusterLocs[e.key]!;
    return {
      'key': e.key,
      'lat': loc['lat'],
      'lng': loc['lng'],
      'stores': e.value,
    };
  }).toList();

  final String viewType = 'naver-web-map-clusters-${clustersData.length}-${validStores.first.id}';

  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final div =
        html.DivElement()
          ..id = 'naver-map-$viewId'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.touchAction = 'none';

    Future.delayed(const Duration(milliseconds: 200), () {
      js.context.callMethod('initNaverMapClusters', [div, js.JsObject.jsify(clustersData), selectedStoreId ?? '']);
    });

    return div;
  });

  return RawGestureDetector(
    gestures: <Type, GestureRecognizerFactory>{
      EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
        () => EagerGestureRecognizer(),
        (EagerGestureRecognizer instance) {},
      ),
    },
    child: HtmlElementView(viewType: viewType),
  );
}

void selectWebMapMarker(String storeId) {
  try {
    js.context.callMethod('selectWebMarker', [storeId]);
  } catch (_) {}
}
