import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/models/order_model.dart';
import 'package:placelist/providers/order_provider.dart';
import 'package:placelist/utils/currency_formatter.dart';

class OrderStatusPage extends ConsumerWidget {
  final String orderId;
  final Order? initialOrder;

  const OrderStatusPage({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orderStream = ref.watch(activeOrderStreamProvider(orderId));

    final currentOrder = orderStream.maybeWhen(
      data: (order) => order ?? initialOrder,
      orElse: () => initialOrder,
    );

    if (currentOrder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('주문 상세')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final status = currentOrder.status;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '픽업 주문 현황',
          style: GoogleFonts.notoSans(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Order Number Badge Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF4A40E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '주문 번호',
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentOrder.orderNumber,
                    style: GoogleFonts.notoSans(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.label,
                      style: GoogleFonts.notoSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Timeline Steps
            Text(
              '진행 상황',
              style: GoogleFonts.notoSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildTimelineStep(
              context: context,
              title: '주문 접수 대기',
              subtitle: '매장에서 주문을 확인하고 있습니다.',
              isDone: status.index >= OrderStatus.pending.index,
              isActive: status == OrderStatus.pending,
              isDark: isDark,
            ),
            _buildTimelineStep(
              context: context,
              title: '음료 제조 중',
              subtitle: '사장님이 바리스타 음료를 만들고 있습니다.',
              isDone: status.index >= OrderStatus.preparing.index,
              isActive: status == OrderStatus.accepted || status == OrderStatus.preparing,
              isDark: isDark,
            ),
            _buildTimelineStep(
              context: context,
              title: '픽업 준비 완료 🎉',
              subtitle: '카운터에서 음료를 픽업해주세요.',
              isDone: status.index >= OrderStatus.ready.index,
              isActive: status == OrderStatus.ready,
              isDark: isDark,
              isLast: true,
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Order Detail Items List
            Text(
              '주문 내역 상세',
              style: GoogleFonts.notoSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  ...currentOrder.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.menuName} x${item.quantity}',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (item.selectedOptions != null &&
                                    item.selectedOptions!.isNotEmpty)
                                  Text(
                                    item.selectedOptions!,
                                    style: GoogleFonts.notoSans(
                                      fontSize: 12,
                                      color: isDark ? Colors.white54 : Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${formatCurrency(item.subtotal)}원',
                            style: GoogleFonts.notoSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '총 결제 금액',
                        style: GoogleFonts.notoSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${formatCurrency(currentOrder.totalAmount)}원',
                        style: GoogleFonts.notoSans(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6C63FF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isActive,
    required bool isDark,
    bool isLast = false,
  }) {
    final color = isActive
        ? const Color(0xFF6C63FF)
        : (isDone ? Colors.green : (isDark ? Colors.white24 : Colors.grey.shade300));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isDone || isActive ? Icons.check : Icons.circle,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDone ? Colors.green : (isDark ? Colors.white10 : Colors.grey.shade300),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSans(
                      fontSize: 15,
                      fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.normal,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
