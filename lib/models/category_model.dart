import 'package:flutter/foundation.dart';

@immutable
class Category {
  final String id;
  final String label;
  final String group;

  const Category({
    required this.id,
    required this.label,
    required this.group,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
