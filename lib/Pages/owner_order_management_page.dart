import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/models/order_model.dart';
import 'package:placelist/providers/order_provider.dart';
import 'package:placelist/utils/currency_formatter.dart';

class OwnerOrderManagementPage extends ConsumerWidget {
  final String storeId;
  final String storeName;

  const OwnerOrderManagementPage({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ordersStream = ref.watch(ownerStoreOrdersProvider(storeId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$storeName 사장님 주문 관리',
              style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '실시간 주문 접수 및 제조 현황',
              style: GoogleFonts.notoSans(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(ownerStoreOrdersProvider(storeId));
            },
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: ordersStream.when(
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.coffee_rounded, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    '접수된 주문이 없습니다.',
                    style: GoogleFonts.notoSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildOrderCard(context, order, isDark);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('에러 발생: $error')),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order, bool isDark) {
    final timeStr = formatTime(order.createdAt);

    Color statusColor;
    switch (order.status) {
      case OrderStatus.pending:
        statusColor = Colors.orange;
        break;
      case OrderStatus.accepted:
      case OrderStatus.preparing:
        statusColor = const Color(0xFF6C63FF);
        break;
      case OrderStatus.ready:
        statusColor = Colors.green;
        break;
      case OrderStatus.completed:
        statusColor = Colors.grey;
        break;
      case OrderStatus.cancelled:
        statusColor = Colors.red;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Order Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.orderNumber,
                        style: GoogleFonts.notoSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      timeStr,
                      style: GoogleFonts.notoSans(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Text(
                  order.status.label,
                  style: GoogleFonts.notoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Customer info
            Text(
              '주문자: ${order.userName}',
              style: GoogleFonts.notoSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (order.userNote != null && order.userNote!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '요청사항: ${order.userNote}',
                  style: GoogleFonts.notoSans(
                    fontSize: 12,
                    color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Order items
            Column(
              children: order.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.menuName} x${item.quantity} ${item.selectedOptions != null && item.selectedOptions!.isNotEmpty ? '(${item.selectedOptions})' : ''}',
                          style: GoogleFonts.notoSans(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        '${formatCurrency(item.subtotal)}원',
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '합계: ${formatCurrency(order.totalAmount)}원',
                style: GoogleFonts.notoSans(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6C63FF),
                ),
              ),
            ),

            // Action Buttons for Store Owner
            const SizedBox(height: 16),
            Row(
              children: [
                if (order.status == OrderStatus.pending) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => OrderService.updateOrderStatus(
                          order.id, OrderStatus.cancelled),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('주문 거절'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => OrderService.updateOrderStatus(
                          order.id, OrderStatus.preparing),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('주문 접수'),
                    ),
                  ),
                ],
                if (order.status == OrderStatus.preparing ||
                    order.status == OrderStatus.accepted) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => OrderService.updateOrderStatus(
                          order.id, OrderStatus.ready),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('제조 완료 (알림 전송)'),
                    ),
                  ),
                ],
                if (order.status == OrderStatus.ready) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => OrderService.updateOrderStatus(
                          order.id, OrderStatus.completed),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('픽업 완료 처리'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
