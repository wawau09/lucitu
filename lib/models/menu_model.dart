class MenuOptionItem {
  final String name;
  final int additionalPrice;

  MenuOptionItem({required this.name, this.additionalPrice = 0});

  factory MenuOptionItem.fromMap(Map<String, dynamic> map) {
    return MenuOptionItem(
      name: map['name']?.toString() ?? '',
      additionalPrice: (map['price'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': additionalPrice,
    };
  }
}

class MenuOptionGroup {
  final String title; // e.g. "온도 선택", "샷 추가", "사이즈"
  final bool isRequired;
  final bool isMultiSelect;
  final List<MenuOptionItem> items;

  MenuOptionGroup({
    required this.title,
    this.isRequired = false,
    this.isMultiSelect = false,
    required this.items,
  });

  factory MenuOptionGroup.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    final itemsList = <MenuOptionItem>[];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map<String, dynamic>) {
          itemsList.add(MenuOptionItem.fromMap(it));
        }
      }
    }
    return MenuOptionGroup(
      title: map['title']?.toString() ?? '',
      isRequired: map['is_required'] == true,
      isMultiSelect: map['is_multi_select'] == true,
      items: itemsList,
    );
  }
}

class MenuItem {
  final String id;
  final String storeId;
  final String category;
  final String name;
  final int price;
  final String? description;
  final String? imageUrl;
  final bool isAvailable;
  final List<MenuOptionGroup> optionGroups;
  final int sortOrder;

  MenuItem({
    required this.id,
    required this.storeId,
    required this.category,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.isAvailable = true,
    List<MenuOptionGroup>? optionGroups,
    this.sortOrder = 0,
  }) : optionGroups = optionGroups ?? [];

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    final rawGroups = map['options'];
    final groupsList = <MenuOptionGroup>[];
    if (rawGroups is List) {
      for (final g in rawGroups) {
        if (g is Map<String, dynamic>) {
          groupsList.add(MenuOptionGroup.fromMap(g));
        }
      }
    }

    return MenuItem(
      id: map['id']?.toString() ?? '',
      storeId: map['store_id']?.toString() ?? '',
      category: map['category']?.toString() ?? '음료',
      name: map['name']?.toString() ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      description: map['description']?.toString(),
      imageUrl: map['image_url']?.toString(),
      isAvailable: map['is_available'] != false,
      optionGroups: groupsList,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
