import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:placelist/models/menu_model.dart';
import 'package:placelist/models/order_model.dart';
import 'package:placelist/providers/cart_provider.dart';
import 'package:placelist/services/kakao_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

final supabaseClient = Supabase.instance.client;

/// Provider to fetch menus for a store
final storeMenusProvider =
    FutureProvider.family<List<MenuItem>, String>((ref, storeId) async {
  try {
    final response = await supabaseClient
        .from('store_menus')
        .select()
        .eq('store_id', storeId)
        .order('sort_order', ascending: true);

    final list = (response as List)
        .map((e) => MenuItem.fromMap(e as Map<String, dynamic>))
        .toList();

    if (list.isNotEmpty) return list;
  } catch (e) {
    debugPrint('Error fetching store_menus from Supabase: $e');
  }

  // Default Fallback Sample Menus for Demonstration if store_menus has no rows yet
  return [
    MenuItem(
      id: 'm1',
      storeId: storeId,
      category: '커피',
      name: '시그니처 아메리카노',
      price: 4500,
      description: '고소한 견과류 풍미와 다크 초콜릿의 묵직한 바디감이 특징인 시그니처 에스프레소 음료.',
      imageUrl: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=400&q=80',
      optionGroups: [
        MenuOptionGroup(
          title: '온도 선택',
          isRequired: true,
          items: [
            MenuOptionItem(name: 'HOT'),
            MenuOptionItem(name: 'ICE'),
          ],
        ),
        MenuOptionGroup(
          title: '옵션 추가',
          isMultiSelect: true,
          items: [
            MenuOptionItem(name: '에스프레소 샷 추가', additionalPrice: 500),
            MenuOptionItem(name: '디카페인 변경', additionalPrice: 500),
            MenuOptionItem(name: '바닐라 시럽 추가', additionalPrice: 500),
          ],
        ),
      ],
    ),
    MenuItem(
      id: 'm2',
      storeId: storeId,
      category: '커피',
      name: '바닐라 빈 라떼',
      price: 5500,
      description: '천연 바닐라 빈을 직접 끓여 만든 스페셜티 시럽과 부드러운 우유의 어우러짐.',
      imageUrl: 'https://images.unsplash.com/photo-1534778101976-62847782c213?auto=format&fit=crop&w=400&q=80',
      optionGroups: [
        MenuOptionGroup(
          title: '온도 선택',
          isRequired: true,
          items: [
            MenuOptionItem(name: 'HOT'),
            MenuOptionItem(name: 'ICE'),
          ],
        ),
        MenuOptionGroup(
          title: '우유 변경',
          items: [
            MenuOptionItem(name: '일반 우유'),
            MenuOptionItem(name: '두유 변경', additionalPrice: 0),
            MenuOptionItem(name: '오트(귀리) 우유 변경', additionalPrice: 600),
          ],
        ),
      ],
    ),
    MenuItem(
      id: 'm3',
      storeId: storeId,
      category: '논커피',
      name: '말차 크림 라떼',
      price: 6000,
      description: '제주 유기농 말차의 쌉쌀함과 부드러운 수제 크림이 조화를 이루는 라떼.',
      imageUrl: 'https://images.unsplash.com/photo-1536256263959-770b48d82b0a?auto=format&fit=crop&w=400&q=80',
      optionGroups: [
        MenuOptionGroup(
          title: '온도 선택',
          isRequired: true,
          items: [
            MenuOptionItem(name: 'ICE 전용'),
          ],
        ),
      ],
    ),
    MenuItem(
      id: 'm4',
      storeId: storeId,
      category: '디저트',
      name: '수제 플레인 스콘',
      price: 3800,
      description: '프랑스산 버터의 풍미가 가득한 겉바속촉 수제 스콘.',
      imageUrl: 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?auto=format&fit=crop&w=400&q=80',
    ),
  ];
});

/// Service class for submitting and managing orders
class OrderService {
  static Future<Order?> submitOrder({
    required CartState cartState,
    required String userName,
    String? userPhone,
    String? userNote,
  }) async {
    if (cartState.isEmpty || cartState.storeId == null) return null;

    final user = supabaseClient.auth.currentUser;
    final orderNumChar = String.fromCharCode(65 + Random().nextInt(26));
    final orderNumDigits = (100 + Random().nextInt(900)).toString();
    final orderNumber = '$orderNumChar-$orderNumDigits';

    try {
      final orderData = await supabaseClient
          .from('orders')
          .insert({
            'order_number': orderNumber,
            'store_id': cartState.storeId,
            'user_id': user?.id,
            'user_name': userName.isEmpty ? '손님' : userName,
            'user_phone': userPhone,
            'status': 'pending',
            'total_amount': cartState.totalAmount,
            'user_note': userNote,
            'estimated_minutes': 10,
          })
          .select()
          .single();

      final orderId = orderData['id'].toString();

      final itemsData = cartState.items
          .map(
            (item) => {
              'order_id': orderId,
              'menu_id': item.menuItem.id.length > 30 ? item.menuItem.id : null,
              'menu_name': item.menuItem.name,
              'price': item.unitPrice,
              'quantity': item.quantity,
              'selected_options': item.selectedOptionText,
              'subtotal': item.subtotal,
            },
          )
          .toList();

      await supabaseClient.from('order_items').insert(itemsData);

      final orderItems = cartState.items
          .map((i) => OrderItem(
                menuName: i.menuItem.name,
                price: i.unitPrice,
                quantity: i.quantity,
                selectedOptions: i.selectedOptionText,
                subtotal: i.subtotal,
              ))
          .toList();

      return Order.fromMap(orderData, items: orderItems);
    } catch (e) {
      debugPrint('Error inserting order to Supabase: $e');
      // Fallback local order for demonstration/offline
      final fallbackId = DateTime.now().millisecondsSinceEpoch.toString();
      final orderItems = cartState.items
          .map((i) => OrderItem(
                menuName: i.menuItem.name,
                price: i.unitPrice,
                quantity: i.quantity,
                selectedOptions: i.selectedOptionText,
                subtotal: i.subtotal,
              ))
          .toList();
      return Order(
        id: fallbackId,
        orderNumber: orderNumber,
        storeId: cartState.storeId!,
        userId: user?.id,
        userName: userName.isEmpty ? '손님' : userName,
        userPhone: userPhone,
        status: OrderStatus.pending,
        totalAmount: cartState.totalAmount,
        userNote: userNote,
        createdAt: DateTime.now(),
        items: orderItems,
      );
    }
  }

  static Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      final updatedOrder = await supabaseClient
          .from('orders')
          .update({'status': newStatus.value})
          .eq('id', orderId)
          .select()
          .maybeSingle();

      if (updatedOrder != null && updatedOrder['user_phone'] != null) {
        final phone = updatedOrder['user_phone'].toString();
        final orderNumber = updatedOrder['order_number'].toString();
        KakaoNotificationService.sendNotification(
          userPhone: phone,
          storeName: '플레이스리스트 카페',
          orderNumber: orderNumber,
          status: newStatus,
        );
      }
    } catch (e) {
      debugPrint('Error updating order status: $e');
    }
  }
}

/// Stream provider for listening to active orders in real time
final activeOrderStreamProvider =
    StreamProvider.family<Order?, String>((ref, orderId) {
  final controller = StreamController<Order?>();

  Future<void> fetchOrder() async {
    try {
      final res = await supabaseClient
          .from('orders')
          .select('*, order_items(*)')
          .eq('id', orderId)
          .maybeSingle();

      if (res != null) {
        final rawItems = res['order_items'] as List?;
        final items = rawItems
                ?.map((i) => OrderItem.fromMap(i as Map<String, dynamic>))
                .toList() ??
            [];
        controller.add(Order.fromMap(res, items: items));
      }
    } catch (e) {
      debugPrint('Error fetching stream order: $e');
    }
  }

  fetchOrder();

  final subscription = supabaseClient
      .channel('public:orders:id=eq.$orderId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: orderId,
        ),
        callback: (payload) {
          fetchOrder();
        },
      )
      .subscribe();

  ref.onDispose(() {
    subscription.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

/// Stream provider for Store Owner to listen to incoming store orders
final ownerStoreOrdersProvider =
    StreamProvider.family<List<Order>, String>((ref, storeId) {
  final controller = StreamController<List<Order>>();

  Future<void> fetchAllOrders() async {
    try {
      final res = await supabaseClient
          .from('orders')
          .select('*, order_items(*)')
          .eq('store_id', storeId)
          .order('created_at', ascending: false)
          .limit(30);

      final list = (res as List).map((row) {
        final rawItems = row['order_items'] as List?;
        final items = rawItems
                ?.map((i) => OrderItem.fromMap(i as Map<String, dynamic>))
                .toList() ??
            [];
        return Order.fromMap(row as Map<String, dynamic>, items: items);
      }).toList();

      controller.add(list);
    } catch (e) {
      debugPrint('Error fetching owner orders: $e');
      controller.add([]);
    }
  }

  fetchAllOrders();

  final subscription = supabaseClient
      .channel('public:orders:store_id=eq.$storeId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'store_id',
          value: storeId,
        ),
        callback: (payload) {
          fetchAllOrders();
        },
      )
      .subscribe();

  ref.onDispose(() {
    subscription.unsubscribe();
    controller.close();
  });

  return controller.stream;
});
