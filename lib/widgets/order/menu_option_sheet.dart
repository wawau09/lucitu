import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/models/menu_model.dart';
import 'package:placelist/providers/cart_provider.dart';
import 'package:placelist/utils/currency_formatter.dart';

class MenuOptionSheet extends ConsumerStatefulWidget {
  final String storeId;
  final String storeName;
  final MenuItem menuItem;

  const MenuOptionSheet({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.menuItem,
  });

  @override
  ConsumerState<MenuOptionSheet> createState() => _MenuOptionSheetState();
}

class _MenuOptionSheetState extends ConsumerState<MenuOptionSheet> {
  final Map<String, String> _selectedSingleOptions = {};
  final Set<String> _selectedMultiOptions = {};
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    // Default select first item of required option groups
    for (final group in widget.menuItem.optionGroups) {
      if (!group.isMultiSelect && group.items.isNotEmpty) {
        _selectedSingleOptions[group.title] = group.items.first.name;
      }
    }
  }

  int _calculateUnitPrice() {
    int price = widget.menuItem.price;
    for (final group in widget.menuItem.optionGroups) {
      if (group.isMultiSelect) {
        for (final item in group.items) {
          if (_selectedMultiOptions.contains('${group.title}_${item.name}')) {
            price += item.additionalPrice;
          }
        }
      } else {
        final selectedName = _selectedSingleOptions[group.title];
        if (selectedName != null) {
          final matched = group.items.firstWhere(
            (it) => it.name == selectedName,
            orElse: () => MenuOptionItem(name: ''),
          );
          price += matched.additionalPrice;
        }
      }
    }
    return price;
  }

  String _buildOptionText() {
    final parts = <String>[];
    for (final entry in _selectedSingleOptions.entries) {
      parts.add(entry.value);
    }
    for (final key in _selectedMultiOptions) {
      final itemName = key.split('_').last;
      parts.add(itemName);
    }
    if (parts.isEmpty) return '기본 선택';
    return parts.join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unitPrice = _calculateUnitPrice();
    final totalPrice = unitPrice * _quantity;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle & Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.menuItem.name,
                      style: GoogleFonts.notoSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Menu Options
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image & Description
                    if (widget.menuItem.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          widget.menuItem.imageUrl!,
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => const SizedBox(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (widget.menuItem.description != null &&
                        widget.menuItem.description!.isNotEmpty) ...[
                      Text(
                        widget.menuItem.description!,
                        style: GoogleFonts.notoSans(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Basic Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '기본 가격',
                          style: GoogleFonts.notoSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        Text(
                          '${formatCurrency(widget.menuItem.price)}원',
                          style: GoogleFonts.notoSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),

                    // Option Groups
                    ...widget.menuItem.optionGroups.map((group) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  group.title,
                                  style: GoogleFonts.notoSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (group.isRequired) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '필수',
                                      style: GoogleFonts.notoSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            Column(
                              children: group.items.map((item) {
                                final isSelected = group.isMultiSelect
                                    ? _selectedMultiOptions.contains('${group.title}_${item.name}')
                                    : _selectedSingleOptions[group.title] == item.name;

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (group.isMultiSelect) {
                                        final key = '${group.title}_${item.name}';
                                        if (isSelected) {
                                          _selectedMultiOptions.remove(key);
                                        } else {
                                          _selectedMultiOptions.add(key);
                                        }
                                      } else {
                                        _selectedSingleOptions[group.title] = item.name;
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          group.isMultiSelect
                                              ? (isSelected
                                                  ? Icons.check_box_rounded
                                                  : Icons.check_box_outline_blank_rounded)
                                              : (isSelected
                                                  ? Icons.radio_button_checked_rounded
                                                  : Icons.radio_button_off_rounded),
                                          color: isSelected
                                              ? const Color(0xFF6C63FF)
                                              : (isDark ? Colors.white38 : Colors.grey[400]),
                                          size: 22,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            item.name,
                                            style: GoogleFonts.notoSans(
                                              fontSize: 14,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        if (item.additionalPrice > 0)
                                          Text(
                                            '+${formatCurrency(item.additionalPrice)}원',
                                            style: GoogleFonts.notoSans(
                                              fontSize: 13,
                                              color: isDark ? Colors.white60 : Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Quantity Control
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '수량 선택',
                          style: GoogleFonts.notoSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _quantity > 1
                                    ? () => setState(() => _quantity--)
                                    : null,
                                icon: const Icon(Icons.remove, size: 18),
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '$_quantity',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => setState(() => _quantity++),
                                icon: const Icon(Icons.add, size: 18),
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Add to Cart Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  ref.read(cartProvider.notifier).addItem(
                        storeId: widget.storeId,
                        storeName: widget.storeName,
                        menuItem: widget.menuItem,
                        selectedOptionText: _buildOptionText(),
                        unitPrice: unitPrice,
                        quantity: _quantity,
                      );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${widget.menuItem.name}이(가) 장바구니에 담겼습니다.',
                        style: GoogleFonts.notoSans(),
                      ),
                      backgroundColor: const Color(0xFF6C63FF),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${formatCurrency(totalPrice)}원 장바구니 담기',
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
