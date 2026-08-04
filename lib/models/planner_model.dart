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
