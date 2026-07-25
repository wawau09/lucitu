import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

/// [repaintKey]에 해당하는 위젯을 PNG 이미지로 캡처한 후
/// 시스템 공유 시트를 띄웁니다.
///
/// [shareText] - 공유 시 함께 전달할 텍스트 (미리보기 제목 등)
/// [pixelRatio] - 이미지 해상도 배율 (기본 3.0 = Retina 수준)
Future<void> captureAndShare({
  required GlobalKey repaintKey,
  String shareText = '내 하루 일정을 공유합니다 🌸',
  double pixelRatio = 3.0,
  Rect? sharePositionOrigin, // iPad 팝오버 위치 (선택)
}) async {
  final boundary = repaintKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;

  if (boundary == null) {
    debugPrint('[share_helper] RepaintBoundary를 찾을 수 없습니다.');
    return;
  }

  // 위젯 → ui.Image
  final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
  final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);

  if (byteData == null) {
    debugPrint('[share_helper] 이미지 변환에 실패했습니다.');
    return;
  }

  final Uint8List pngBytes = byteData.buffer.asUint8List();

  final xFile = XFile.fromData(
    pngBytes,
    name: 'loci_plan_${DateTime.now().millisecondsSinceEpoch}.png',
    mimeType: 'image/png',
  );

  // share_plus v10 — static Share.shareXFiles() 사용
  await Share.shareXFiles(
    [xFile],
    text: shareText,
    sharePositionOrigin: sharePositionOrigin,
    fileNameOverrides: ['loci_plan.png'],
  );
}
