import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;

bool _isRegistered = false;

Widget getWebMap() {
  if (!_isRegistered) {
    ui_web.platformViewRegistry.registerViewFactory('naver-web-map', (int viewId) {
      final div = html.DivElement()
        ..id = 'naver-map-$viewId'
        ..style.width = '100%'
        ..style.height = '100%';
      
      Future.delayed(const Duration(milliseconds: 100), () {
        js.context.callMethod('initNaverMap', [div.id]);
      });
      
      return div;
    });
    _isRegistered = true;
  }
  return const HtmlElementView(viewType: 'naver-web-map');
}
