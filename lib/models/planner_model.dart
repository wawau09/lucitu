class Participant {
  final String id;
  final String name;
  final String emoji;
  final String role;
  final String email;

  Participant({
    required this.id,
    required this.name,
    required this.emoji,
    required this.role,
    required this.email,
  });

  factory Participant.fromRoleString(String id, String email, String roleStr) {
    final parts = roleStr.split('|');
    if (parts.length >= 3) {
      return Participant(
        id: id,
        name: parts[0],
        emoji: parts[1],
        role: parts[2],
        email: email,
      );
    }
    return Participant(
      id: id,
      name: email.split('@').first,
      emoji: '✈️',
      role: roleStr,
      email: email,
    );
  }

  String toRoleString() {
    return '$name|$emoji|$role';
  }
}

class TravelEvent {
  final String id;
  final String title;
  final String startTime;
  final String? endTime;
  final String category; // 관광, 식도락, 숙소, 교통, 기타
  final int cost;
  final String status; // Todo, In Progress, Done
  final String description;
  final List<String> participantNames;
  final int sortOrder;

  TravelEvent({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    required this.category,
    required this.cost,
    required this.status,
    required this.description,
    required this.participantNames,
    required this.sortOrder,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'startTime': startTime,
        'endTime': endTime,
        'category': category,
        'cost': cost,
        'status': status,
        'description': description,
        'participantNames': participantNames,
        'sortOrder': sortOrder,
      };

  factory TravelEvent.fromMap(Map<String, dynamic> map) => TravelEvent(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        startTime: map['startTime']?.toString() ?? '',
        endTime: map['endTime']?.toString(),
        category: map['category']?.toString() ?? '관광',
        cost: map['cost'] is num ? (map['cost'] as num).toInt() : 0,
        status: map['status']?.toString() ?? 'Todo',
        description: map['description']?.toString() ?? '',
        participantNames: List<String>.from(map['participantNames'] ?? []),
        sortOrder: map['sortOrder'] is num ? (map['sortOrder'] as num).toInt() : 0,
      );
}

class ChecklistItem {
  final String id;
  final String title;
  bool checked;
  final int sortOrder;

  ChecklistItem({
    required this.id,
    required this.title,
    required this.checked,
    required this.sortOrder,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'checked': checked,
        'sortOrder': sortOrder,
      };

  factory ChecklistItem.fromMap(Map<String, dynamic> map) => ChecklistItem(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        checked: map['checked'] == true,
        sortOrder: map['sortOrder'] is num ? (map['sortOrder'] as num).toInt() : 0,
      );
}
