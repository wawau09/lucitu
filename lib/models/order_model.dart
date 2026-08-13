enum OrderStatus {
  pending, // 주문 접수 대기
  accepted, // 주문 승인
  preparing, // 제조 중
  ready, // 픽업 준비 완료
  completed, // 픽업 완료
  cancelled, // 주문 취소
}

extension OrderStatusExtension on OrderStatus {
  String get value {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.accepted:
        return 'accepted';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return '주문 접수 대기';
      case OrderStatus.accepted:
        return '주문 승인됨';
      case OrderStatus.preparing:
        return '음료 제조 중 ☕';
      case OrderStatus.ready:
        return '픽업 대기 🎉';
      case OrderStatus.completed:
        return '픽업 완료';
      case OrderStatus.cancelled:
        return '주문 취소됨';
    }
  }

  static OrderStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'accepted':
        return OrderStatus.accepted;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'pending':
      default:
        return OrderStatus.pending;
    }
  }
}

class OrderItem {
  final String? id;
  final String? menuId;
  final String menuName;
  final int price;
  final int quantity;
  final String? selectedOptions;
  final int subtotal;

  OrderItem({
    this.id,
    this.menuId,
    required this.menuName,
    required this.price,
    required this.quantity,
    this.selectedOptions,
    required this.subtotal,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id']?.toString(),
      menuId: map['menu_id']?.toString(),
      menuName: map['menu_name']?.toString() ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      selectedOptions: map['selected_options']?.toString(),
      subtotal: (map['subtotal'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap(String orderId) {
    return {
      'order_id': orderId,
      if (menuId != null) 'menu_id': menuId,
      'menu_name': menuName,
      'price': price,
      'quantity': quantity,
      'selected_options': selectedOptions,
      'subtotal': subtotal,
    };
  }
}

class Order {
  final String id;
  final String orderNumber;
  final String storeId;
  final String? userId;
  final String userName;
  final String? userPhone;
  final OrderStatus status;
  final int totalAmount;
  final String? userNote;
  final int estimatedMinutes;
  final DateTime createdAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.orderNumber,
    required this.storeId,
    this.userId,
    required this.userName,
    this.userPhone,
    required this.status,
    required this.totalAmount,
    this.userNote,
    this.estimatedMinutes = 10,
    required this.createdAt,
    List<OrderItem>? items,
  }) : items = items ?? [];

  factory Order.fromMap(Map<String, dynamic> map, {List<OrderItem>? items}) {
    return Order(
      id: map['id']?.toString() ?? '',
      orderNumber: map['order_number']?.toString() ?? '',
      storeId: map['store_id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      userName: map['user_name']?.toString() ?? '손님',
      userPhone: map['user_phone']?.toString(),
      status: OrderStatusExtension.fromString(map['status']?.toString() ?? 'pending'),
      totalAmount: (map['total_amount'] as num?)?.toInt() ?? 0,
      userNote: map['user_note']?.toString(),
      estimatedMinutes: (map['estimated_minutes'] as num?)?.toInt() ?? 10,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      items: items ?? [],
    );
  }
}
