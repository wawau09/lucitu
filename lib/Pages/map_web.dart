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
          ..style.height = '100%';

    Future.delayed(const Duration(milliseconds: 200), () {
      js.context.callMethod('initNaverMap', [div, lat, lng, name]);
    });

    return div;
  });

  return HtmlElementView(viewType: viewType);
}

Widget getWebMapStores(List<Store> stores) {
  final validStores = stores.where((s) => s.latitude != null && s.longitude != null).toList();
  if (validStores.isEmpty) {
    return const Center(child: Text("지도에 표시할 위치 정보가 없습니다."));
  }

  final String viewType = 'naver-web-map-multi-${validStores.length}-${validStores.first.id}';

  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final div =
        html.DivElement()
          ..id = 'naver-map-$viewId'
          ..style.width = '100%'
          ..style.height = '100%';

    final storesData = validStores.map((s) => {
      'lat': s.latitude,
      'lng': s.longitude,
      'name': s.name,
      'id': s.id,
      'rating': s.rating ?? 0.0,
      'region': s.region ?? '',
    }).toList();

    Future.delayed(const Duration(milliseconds: 200), () {
      js.context.callMethod('initNaverMapMulti', [div, js.JsObject.jsify(storesData)]);
    });

    return div;
  });

  return HtmlElementView(viewType: viewType);
}
