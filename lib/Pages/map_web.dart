import 'package:flutter/material.dart';
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;

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
