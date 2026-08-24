import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;
import 'package:placelist/DB/store.dart';
import 'package:placelist/utils/map_utils.dart';

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
  final mapStoreItems = groupStoresByLocation(stores);
  if (mapStoreItems.isEmpty) {
    return const Center(child: Text("지도에 표시할 위치 정보가 없습니다."));
  }

  if (onStoreSelected != null) {
    js.context['flutterOnSelectStore'] = (String storeId) {
      onStoreSelected(storeId);
    };
  }

  final String viewType = 'naver-web-map-multi-${mapStoreItems.length}-${mapStoreItems.first.store.id}';

  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final div =
        html.DivElement()
          ..id = 'naver-map-$viewId'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.touchAction = 'none';

    final storesData = mapStoreItems.map((item) => {
      'lat': item.displayLat,
      'lng': item.displayLng,
      'name': item.store.name,
      'id': item.store.id ?? '',
      'rating': item.store.rating ?? 0.0,
      'region': item.store.region ?? '',
      'clusterIndex': item.clusterIndex,
      'clusterTotal': item.clusterTotal,
    }).toList();

    Future.delayed(const Duration(milliseconds: 200), () {
      js.context.callMethod('initNaverMapMulti', [div, js.JsObject.jsify(storesData), selectedStoreId ?? '']);
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
