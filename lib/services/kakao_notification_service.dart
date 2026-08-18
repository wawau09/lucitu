import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:placelist/models/order_model.dart';

/// KakaoTalk Alimtalk & Notification Service
/// Handles Kakao Alimtalk messaging trigger for order status updates.
class KakaoNotificationService {
  // Configurable Alimtalk Provider REST API settings (Solapi / Kakao Bizmessage / Webhook)
  static String? alimtalkApiKey;
  static String? alimtalkApiSecret;
  static String? pfId; // Kakao Plus Friend ID
  static String? webhookUrl; // Supabase Edge function or custom webhook URL

  /// Formats the notification message text based on the order status
  static String generateMessageText({
    required String storeName,
    required String orderNumber,
    required OrderStatus status,
    int? estimatedMinutes,
  }) {
    switch (status) {
      case OrderStatus.pending:
        return '[주문 접수 대기]\n[$storeName]\n주문번호: $orderNumber\n손님의 주문이 매장에 전달되었습니다. 매장 확인 중입니다.';
      case OrderStatus.accepted:
      case OrderStatus.preparing:
        return '[주문 접수 완료]\n[$storeName]\n주문번호: $orderNumber\n주문이 접수되어 메뉴 조리가 시작되었습니다.\n예상 소요시간: 약 ${estimatedMinutes ?? 10}분';
      case OrderStatus.ready:
        return '[메뉴 준비 완료]\n[$storeName]\n주문번호: $orderNumber\n주문하신 메뉴가 준비되었습니다! 카운터에서 픽업해 주세요.';
      case OrderStatus.completed:
        return '[픽업 완료]\n[$storeName]\n주문번호: $orderNumber\n맛있게 드세요! 이용해 주셔서 감사합니다.';
      case OrderStatus.cancelled:
        return '[주문 취소 안내]\n[$storeName]\n주문번호: $orderNumber\n매장 사정으로 인해 주문이 취소되었습니다. 불편을 드려 죄송합니다.';
    }
  }

  /// Sends KakaoTalk Notification message via Alimtalk REST API / Webhook
  static Future<bool> sendNotification({
    required String userPhone,
    required String storeName,
    required String orderNumber,
    required OrderStatus status,
    int? estimatedMinutes,
  }) async {
    if (userPhone.isEmpty) {
      debugPrint('[KakaoNotification] Phone number is empty. Skipping notification.');
      return false;
    }

    final cleanPhone = userPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final message = generateMessageText(
      storeName: storeName,
      orderNumber: orderNumber,
      status: status,
      estimatedMinutes: estimatedMinutes,
    );

    debugPrint('====================================================');
    debugPrint('[KakaoNotification] Sending KakaoTalk Alimtalk Message:');
    debugPrint('To: $cleanPhone');
    debugPrint('Status: ${status.label}');
    debugPrint('Content:\n$message');
    debugPrint('====================================================');

    // If Webhook URL is set, dispatch HTTP POST request
    if (webhookUrl != null && webhookUrl!.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse(webhookUrl!),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': cleanPhone,
            'store_name': storeName,
            'order_number': orderNumber,
            'status': status.value,
            'message': message,
          }),
        );
        debugPrint('[KakaoNotification] Webhook Response Status: ${response.statusCode}');
        return response.statusCode >= 200 && response.statusCode < 300;
      } catch (e) {
        debugPrint('[KakaoNotification] Error calling Webhook: $e');
        return false;
      }
    }

    // Direct Solapi / Kakao Alimtalk REST API Integration Mock / Client Call
    return true;
  }
}
