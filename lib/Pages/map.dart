import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'map_stub.dart' if (dart.library.html) 'map_web.dart';

class MapPage extends StatefulWidget{
  const MapPage({super.key});

  @override
  State<MapPage> createState() => Map();
}

class Map extends State<MapPage> {
   @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return getWebMap();
    }

    // NaverMapController 객체의 비동기 작업 완료를 나타내는 Completer 생성
    final Completer<NaverMapController> mapControllerCompleter = Completer();

    return MaterialApp(
      home: Scaffold(
        body: NaverMap(
          options: const NaverMapViewOptions(
            indoorEnable: true,             // 실내 맵 사용 가능 여부 설정
            locationButtonEnable: false,    // 위치 버튼 표시 여부 설정
            consumeSymbolTapEvents: true,  // 심볼 탭 이벤트 소비 여부 설정
            initialCameraPosition: NCameraPosition(
              target: NLatLng(35.1, 128.95),
              zoom: 12,
              bearing: 0,
              tilt: 0,
            ),
          ),
          onMapReady: (controller) async {                // 지도 준비 완료 시 호출되는 콜백 함수
            mapControllerCompleter.complete(controller);  // Completer에 지도 컨트롤러 완료 신호 전송
            final marker = NMarker(
                id: '0',
                size: Size(30, 40),
                position: NLatLng(35.10658, 128.9663));
            final marker1 = NMarker(
                id: '1',
                position: NLatLng(35.15571, 129.0596));
            controller.addOverlayAll({marker, marker1});
            
            final OnMarkerInfoMap =
                NInfoWindow.onMarker(id: marker.info.id, text: "아트몰링");
            marker.openInfoWindow(OnMarkerInfoMap);

            final OnMarkerInfo =
                NInfoWindow.onMarker(id: marker1.info.id, text: "내공초밥");
            marker1.openInfoWindow(OnMarkerInfo);
          },
        ),
      ),
    );
  }
}