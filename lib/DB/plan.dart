class PlanSummary {
  PlanSummary({
    required this.id,
    required this.name,
    required this.planDate,
    required this.planCode,
    required this.ownerId,
    required this.isOwner,
    required this.sharedWithMe,
    required this.itemCount,
  });

  final String id;
  final String name;
  final DateTime planDate;
  final String planCode;
  final String ownerId;
  final bool isOwner;
  final bool sharedWithMe;
  final int itemCount;

  factory PlanSummary.fromMap(
    Map<String, dynamic> map, {
    required String currentUserId,
  }) {
    final ownerId = map['owner_id']?.toString() ?? '';
    return PlanSummary(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '\uC774\uB984 \uC5C6\uB294 \uACC4\uD68D',
      planDate: DateTime.tryParse(map['plan_date']?.toString() ?? '') ??
          DateTime.now(),
      planCode: map['plan_code']?.toString() ?? '',
      ownerId: ownerId,
      isOwner: ownerId == currentUserId,
      sharedWithMe: ownerId != currentUserId,
      itemCount: map['item_count'] is num
          ? (map['item_count'] as num).toInt()
          : int.tryParse(map['item_count']?.toString() ?? '') ?? 0,
    );
  }
}

class PlanCollaborator {
  PlanCollaborator({
    required this.email,
    required this.role,
    required this.createdAt,
    this.isSelf = false,
  });

  final String email;
  final String role;
  final DateTime createdAt;
  final bool isSelf;

  factory PlanCollaborator.fromMap(
    Map<String, dynamic> map, {
    String? currentEmail,
  }) {
    final email = map['collaborator_email']?.toString() ?? '';
    return PlanCollaborator(
      email: email,
      role: map['role']?.toString() ?? 'editor',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isSelf: currentEmail != null && email.toLowerCase() == currentEmail,
    );
  }
}

class PlanItem {
  PlanItem({
    required this.id,
    required this.planId,
    required this.title,
    required this.sortOrder,
    this.placeName,
    this.startTime,
    this.endTime,
    this.note,
  });

  final String id;
  final String planId;
  final String title;
  final int sortOrder;
  final String? placeName;
  final String? startTime;
  final String? endTime;
  final String? note;

  factory PlanItem.fromMap(Map<String, dynamic> map) {
    return PlanItem(
      id: map['id']?.toString() ?? '',
      planId: map['plan_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '\uBBF8\uC815\uC758 \uC77C\uC815',
      placeName: map['place_name']?.toString(),
      startTime: map['start_time']?.toString(),
      endTime: map['end_time']?.toString(),
      note: map['note']?.toString(),
      sortOrder: map['sort_order'] is num
          ? (map['sort_order'] as num).toInt()
          : int.tryParse(map['sort_order']?.toString() ?? '') ?? 0,
    );
  }
}

class PlanDetail {
  PlanDetail({
    required this.plan,
    required this.collaborators,
    required this.items,
  });

  final PlanSummary plan;
  final List<PlanCollaborator> collaborators;
  final List<PlanItem> items;
}

class PlanDraft {
  PlanDraft({
    required this.title,
    this.placeName,
    this.startTime,
    this.endTime,
    this.note,
  });

  final String title;
  final String? placeName;
  final String? startTime;
  final String? endTime;
  final String? note;
}
