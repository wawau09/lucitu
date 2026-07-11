import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ----------------------------------------------------
// Models for Travel Planner Dashboard
// ----------------------------------------------------

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
}

// ----------------------------------------------------
// Cupertino Travel Planner Dashboard Page
// ----------------------------------------------------

class PlanDetailPage extends ConsumerStatefulWidget {
  const PlanDetailPage({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends ConsumerState<PlanDetailPage> {
  bool _isLoading = true;
  bool _isOffline = false;

  // Local state arrays
  List<Participant> _participants = [];
  List<TravelEvent> _events = [];
  List<ChecklistItem> _checklist = [];

  String _planName = '';
  DateTime _planDate = DateTime(2026, 7, 12);
  String _planCode = '';

  bool? _isDarkOverride;

  // Filter and Search states
  String _searchQuery = '';
  String _selectedCategoryFilter = '전체'; // 전체, 관광, 식도락, 숙소, 교통, 기타

  // Text controller for adding checklist items
  final TextEditingController _checklistInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPlanData();
  }

  @override
  void dispose() {
    _checklistInputController.dispose();
    super.dispose();
  }

  /// Dynamic D-Day calculations
  String _getDDayString(DateTime targetDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final difference = target.difference(today).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference > 0) {
      return 'D-$difference';
    } else {
      return 'D+${difference.abs()}';
    }
  }

  /// Format numbers as KRW with commas: 120000 -> ₩120,000
  String _formatKRW(int amount) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final str = absAmount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return '${isNegative ? '-' : ''}₩${buffer.toString()}';
  }

  /// Sync data from Supabase
  Future<void> _fetchPlanData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _loadLocalMockData();
        setState(() => _isLoading = false);
        return;
      }

      // Fetch plan summary first to get Name, Date, Code
      final planRow = await Supabase.instance.client
          .from('plans')
          .select()
          .eq('id', widget.planId)
          .maybeSingle();

      if (planRow == null) {
        _loadLocalMockData();
        setState(() => _isLoading = false);
        return;
      }

      final dateStr = planRow['plan_date']?.toString() ?? '';
      final parsedDate = DateTime.tryParse(dateStr) ?? DateTime(2026, 7, 12);

      final collabs = await Supabase.instance.client
          .from('plan_collaborators')
          .select()
          .eq('plan_id', widget.planId);

      final items = await Supabase.instance.client
          .from('plan_items')
          .select()
          .eq('plan_id', widget.planId)
          .order('sort_order');

      final List<Participant> loadedParticipants = [];
      for (var row in collabs) {
        final email = row['collaborator_email']?.toString() ?? '';
        final roleStr = row['role']?.toString() ?? '';
        final id = row['id']?.toString() ?? '';
        loadedParticipants.add(Participant.fromRoleString(id, email, roleStr));
      }

      final List<TravelEvent> loadedEvents = [];
      final List<ChecklistItem> loadedChecklist = [];

      for (var row in items) {
        final title = row['title']?.toString() ?? '';
        final startTime = row['start_time']?.toString() ?? '';
        final noteStr = row['note']?.toString() ?? '';
        Map<String, dynamic> noteMap = {};
        try {
          if (noteStr.isNotEmpty) {
            noteMap = Map<String, dynamic>.from(jsonDecode(noteStr));
          }
        } catch (_) {}

        final category = noteMap['category']?.toString() ?? '';
        if (category == 'checklist') {
          loadedChecklist.add(ChecklistItem(
            id: row['id']?.toString() ?? '',
            title: title,
            checked: noteMap['checked'] == true,
            sortOrder: row['sort_order'] is num ? (row['sort_order'] as num).toInt() : 0,
          ));
        } else {
          loadedEvents.add(TravelEvent(
            id: row['id']?.toString() ?? '',
            title: title,
            startTime: startTime,
            category: category.isNotEmpty ? category : '관광',
            cost: noteMap['cost'] is num ? (noteMap['cost'] as num).toInt() : 0,
            status: noteMap['status']?.toString() ?? 'Todo',
            description: noteMap['description']?.toString() ?? '',
            participantNames: List<String>.from(noteMap['participants'] ?? []),
            sortOrder: row['sort_order'] is num ? (row['sort_order'] as num).toInt() : 0,
          ));
        }
      }

      setState(() {
        _planName = planRow['name']?.toString() ?? '';
        _planDate = parsedDate;
        _planCode = planRow['plan_code']?.toString() ?? '';
        _participants = loadedParticipants;
        _events = loadedEvents;
        _checklist = loadedChecklist;
        _isOffline = false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching data: $e');
      _loadLocalMockData();
      setState(() => _isLoading = false);
    }
  }

  void _loadLocalMockData() {
    _planName = '우리들의 감성 제주';
    _planDate = DateTime(2026, 7, 12);
    _planCode = 'PL-MOCK-1234';
    _participants = [
      Participant(id: 'mock_p1', name: '민수', emoji: '🐶', role: '드라이버 🚗', email: 'minsu@traveler.com'),
      Participant(id: 'mock_p2', name: '수연', emoji: '🐱', role: '총무 💰', email: 'suyeon@traveler.com'),
      Participant(id: 'mock_p3', name: '지현', emoji: '🦊', role: '촬영기사 📸', email: 'jihyun@traveler.com'),
    ];
    _events = [
      TravelEvent(
        id: 'mock_e1',
        title: '✈️ 제주공항 도착',
        startTime: '09:00',
        category: '관광',
        cost: 0,
        status: 'Done',
        description: '설레는 제주 여행 시작! 렌터카 인수 및 아침 식사 이동',
        participantNames: ['민수', '수연', '지현'],
        sortOrder: 0,
      ),
      TravelEvent(
        id: 'mock_e2',
        title: '🍔 애월 더클리프',
        startTime: '10:30',
        category: '식도락',
        cost: 45000,
        status: 'In Progress',
        description: '바다 뷰를 보며 맛있는 수제버거와 칵테일 한 잔',
        participantNames: ['민수', '수연', '지현'],
        sortOrder: 1,
      ),
      TravelEvent(
        id: 'mock_e3',
        title: '🗺️ 협재해수욕장 산책',
        startTime: '13:00',
        category: '관광',
        cost: 5000,
        status: 'Todo',
        description: '에메랄드빛 바다와 비양도를 배경으로 인생샷 남기기',
        participantNames: ['민수', '지현'],
        sortOrder: 2,
      ),
      TravelEvent(
        id: 'mock_e4',
        title: '🛍️ 동문시장 기념품 쇼핑',
        startTime: '15:30',
        category: '기타',
        cost: 60000,
        status: 'Todo',
        description: '오메기떡과 감귤 초콜릿 쇼핑',
        participantNames: ['수연', '지현'],
        sortOrder: 3,
      ),
      TravelEvent(
        id: 'mock_e5',
        title: '🏨 서귀포 숙소 체크인',
        startTime: '18:00',
        category: '숙소',
        cost: 120000,
        status: 'Todo',
        description: '아늑한 한옥 펜션에서 짐 풀고 휴식',
        participantNames: ['민수', '수연', '지현'],
        sortOrder: 4,
      ),
    ];
    _checklist = [
      ChecklistItem(id: 'mock_c1', title: '신분증 & 운전면허증 🪪', checked: true, sortOrder: 0),
      ChecklistItem(id: 'mock_c2', title: '카메라 & 보조배터리 🔋', checked: true, sortOrder: 1),
      ChecklistItem(id: 'mock_c3', title: '편안한 운동화 👟', checked: false, sortOrder: 2),
      ChecklistItem(id: 'mock_c4', title: '선크림 & 선글라스 🕶️', checked: false, sortOrder: 3),
    ];
    _isOffline = true;
  }

  /// Add Participant with Supabase Sync
  Future<void> _addParticipant(String name, String emoji, String role) async {
    final email = '${name.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch % 1000}@traveler.com';
    final roleString = '$name|$emoji|$role';
    if (!_isOffline) {
      try {
        final row = await Supabase.instance.client.from('plan_collaborators').insert({
          'plan_id': widget.planId,
          'collaborator_email': email,
          'role': roleString,
        }).select().single();
        setState(() {
          _participants.add(Participant(
            id: row['id']?.toString() ?? '',
            name: name,
            emoji: emoji,
            role: role,
            email: email,
          ));
        });
      } catch (e) {
        debugPrint('DB Participant addition error: $e');
        _addParticipantOffline(name, emoji, role, email);
      }
    } else {
      _addParticipantOffline(name, emoji, role, email);
    }
  }

  void _addParticipantOffline(String name, String emoji, String role, String email) {
    final localId = 'local_p_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _participants.add(Participant(id: localId, name: name, emoji: emoji, role: role, email: email));
    });
  }

  /// Delete Participant with Supabase Sync
  Future<void> _deleteParticipant(Participant p) async {
    if (!_isOffline && !p.id.startsWith('mock_') && !p.id.startsWith('local_')) {
      try {
        await Supabase.instance.client
            .from('plan_collaborators')
            .delete()
            .eq('id', p.id);
      } catch (e) {
        debugPrint('DB Participant deletion error: $e');
      }
    }
    setState(() {
      _participants.removeWhere((item) => item.id == p.id);
      for (var e in _events) {
        e.participantNames.remove(p.name);
      }
    });
  }

  /// Add Event with Supabase Sync
  Future<void> _addTravelEvent(TravelEvent newEvent) async {
    if (!_isOffline) {
      try {
        final noteMap = {
          'category': newEvent.category,
          'cost': newEvent.cost,
          'status': newEvent.status,
          'description': newEvent.description,
          'participants': newEvent.participantNames,
        };
        final row = await Supabase.instance.client.from('plan_items').insert({
          'plan_id': widget.planId,
          'title': newEvent.title,
          'start_time': newEvent.startTime,
          'note': jsonEncode(noteMap),
          'sort_order': newEvent.sortOrder,
        }).select().single();

        setState(() {
          _events.add(TravelEvent(
            id: row['id']?.toString() ?? '',
            title: newEvent.title,
            startTime: newEvent.startTime,
            category: newEvent.category,
            cost: newEvent.cost,
            status: newEvent.status,
            description: newEvent.description,
            participantNames: newEvent.participantNames,
            sortOrder: newEvent.sortOrder,
          ));
          _events.sort((a, b) => a.startTime.compareTo(b.startTime));
        });
      } catch (e) {
        debugPrint('DB Event addition error: $e');
        _addEventOffline(newEvent);
      }
    } else {
      _addEventOffline(newEvent);
    }
  }

  void _addEventOffline(TravelEvent event) {
    final localId = 'local_e_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _events.add(TravelEvent(
        id: localId,
        title: event.title,
        startTime: event.startTime,
        category: event.category,
        cost: event.cost,
        status: event.status,
        description: event.description,
        participantNames: event.participantNames,
        sortOrder: event.sortOrder,
      ));
      _events.sort((a, b) => a.startTime.compareTo(b.startTime));
    });
  }

  /// Update Event with Supabase Sync
  Future<void> _updateTravelEvent(TravelEvent updatedEvent) async {
    if (!_isOffline && !updatedEvent.id.startsWith('mock_') && !updatedEvent.id.startsWith('local_')) {
      try {
        final noteMap = {
          'category': updatedEvent.category,
          'cost': updatedEvent.cost,
          'status': updatedEvent.status,
          'description': updatedEvent.description,
          'participants': updatedEvent.participantNames,
        };
        await Supabase.instance.client.from('plan_items').update({
          'title': updatedEvent.title,
          'start_time': updatedEvent.startTime,
          'note': jsonEncode(noteMap),
          'sort_order': updatedEvent.sortOrder,
        }).eq('id', updatedEvent.id);
      } catch (e) {
        debugPrint('DB Event update error: $e');
      }
    }
    setState(() {
      final index = _events.indexWhere((e) => e.id == updatedEvent.id);
      if (index != -1) {
        _events[index] = updatedEvent;
        _events.sort((a, b) => a.startTime.compareTo(b.startTime));
      }
    });
  }

  /// Delete Event with Supabase Sync
  Future<void> _deleteTravelEvent(String eventId) async {
    if (!_isOffline && !eventId.startsWith('mock_') && !eventId.startsWith('local_')) {
      try {
        await Supabase.instance.client
            .from('plan_items')
            .delete()
            .eq('id', eventId);
      } catch (e) {
        debugPrint('DB Event deletion error: $e');
      }
    }
    setState(() {
      _events.removeWhere((e) => e.id == eventId);
    });
  }

  /// Add Checklist Item with Supabase Sync
  Future<void> _addChecklistItem(String title) async {
    final nextOrder = _checklist.length;
    if (!_isOffline) {
      try {
        final noteMap = {
          'category': 'checklist',
          'checked': false,
        };
        final row = await Supabase.instance.client.from('plan_items').insert({
          'plan_id': widget.planId,
          'title': title,
          'note': jsonEncode(noteMap),
          'sort_order': nextOrder,
        }).select().single();

        setState(() {
          _checklist.add(ChecklistItem(
            id: row['id']?.toString() ?? '',
            title: title,
            checked: false,
            sortOrder: nextOrder,
          ));
        });
      } catch (e) {
        debugPrint('DB Checklist add error: $e');
        _addChecklistOffline(title, nextOrder);
      }
    } else {
      _addChecklistOffline(title, nextOrder);
    }
  }

  void _addChecklistOffline(String title, int sortOrder) {
    final localId = 'local_c_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _checklist.add(ChecklistItem(id: localId, title: title, checked: false, sortOrder: sortOrder));
    });
  }

  /// Toggle Checklist Checked Status
  Future<void> _toggleChecklistItem(ChecklistItem item) async {
    final newChecked = !item.checked;
    setState(() {
      item.checked = newChecked;
    });

    if (!_isOffline && !item.id.startsWith('mock_') && !item.id.startsWith('local_')) {
      try {
        final noteMap = {
          'category': 'checklist',
          'checked': newChecked,
        };
        await Supabase.instance.client.from('plan_items').update({
          'note': jsonEncode(noteMap),
        }).eq('id', item.id);
      } catch (e) {
        debugPrint('DB Checklist toggle error: $e');
      }
    }
  }

  /// Delete Checklist Item
  Future<void> _deleteChecklistItem(String id) async {
    if (!_isOffline && !id.startsWith('mock_') && !id.startsWith('local_')) {
      try {
        await Supabase.instance.client.from('plan_items').delete().eq('id', id);
      } catch (e) {
        debugPrint('DB Checklist delete error: $e');
      }
    }
    setState(() {
      _checklist.removeWhere((c) => c.id == id);
    });
  }

  /// Batch Delete Checked Checklist Items
  Future<void> _deleteCheckedItems() async {
    final checkedList = _checklist.where((c) => c.checked).toList();
    for (var item in checkedList) {
      await _deleteChecklistItem(item.id);
    }
  }

  /// Custom color mapping for Avatars
  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFFE57373),
      const Color(0xFFF06292),
      const Color(0xFFBA68C8),
      const Color(0xFF9575CD),
      const Color(0xFF7986CB),
      const Color(0xFF64B5F6),
      const Color(0xFF4FC3F7),
      const Color(0xFF4DB6AC),
      const Color(0xFF81C784),
      const Color(0xFFFFB74D),
    ];
    final index = name.codeUnits.fold(0, (sum, val) => sum + val) % colors.length;
    return colors[index].withOpacity(0.25);
  }

  /// Category breakdown stats for Doughnut Chart
  Map<String, int> _getCategoryBreakdown() {
    final Map<String, int> breakdown = {
      '관광': 0,
      '식도락': 0,
      '숙소': 0,
      '교통': 0,
      '기타': 0,
    };
    for (var e in _events) {
      if (breakdown.containsKey(e.category)) {
        breakdown[e.category] = (breakdown[e.category] ?? 0) + e.cost;
      }
    }
    return breakdown;
  }

  int _getTotalExpense() {
    return _events.fold(0, (sum, e) => sum + e.cost);
  }

  /// Add participant dialog
  void _showAddParticipantDialog() {
    final nameController = TextEditingController();
    final roleController = TextEditingController();
    String selectedEmoji = '🐱';
    final emojiList = ['🐱', '🐶', '🦊', '🐹', '🐰', '🐼', '🐨', '🐯', '🦁', '🦖', '🚗', '💰', '📸', '✈️'];

    showCupertinoDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = _isDarkOverride ?? (Theme.of(context).brightness == Brightness.dark);
            final textStyle = TextStyle(color: isDark ? Colors.white : Colors.black87);

            return CupertinoAlertDialog(
              title: Text('동행자 추가', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold)),
              content: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    CupertinoTextField(
                      controller: nameController,
                      placeholder: '이름 입력',
                      placeholderStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                      style: textStyle,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    const SizedBox(height: 10),
                    CupertinoTextField(
                      controller: roleController,
                      placeholder: '역할 입력 (예: 드라이버 🚗)',
                      placeholderStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                      style: textStyle,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    const SizedBox(height: 16),
                    Text('아바타 에모지 선택', style: GoogleFonts.notoSansKr(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: emojiList.length,
                        itemBuilder: (context, index) {
                          final emoji = emojiList[index];
                          final isSelected = selectedEmoji == emoji;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedEmoji = emoji;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF007AFF).withOpacity(0.2)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(emoji, style: const TextStyle(fontSize: 20)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () {
                    final name = nameController.text.trim();
                    final role = roleController.text.trim();
                    if (name.isNotEmpty && role.isNotEmpty) {
                      _addParticipant(name, selectedEmoji, role);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('추가'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Delete participant confirmation
  void _confirmDeleteParticipant(Participant p) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('${p.name}님을 삭제하시겠습니까?'),
        content: const Text('동행자 리스트 및 일정 담당자 정보에서 제외됩니다.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('취소'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              _deleteParticipant(p);
              Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// Open Cupertino Modal Bottom Sheet for Add/Edit Event
  void _showEventBottomSheet({TravelEvent? existingEvent}) {
    final isEdit = existingEvent != null;
    final titleController = TextEditingController(text: existingEvent?.title ?? '');
    final descController = TextEditingController(text: existingEvent?.description ?? '');
    final costController = TextEditingController(text: existingEvent?.cost.toString() ?? '');
    String selectedCategory = existingEvent?.category ?? '관광';
    String selectedTime = existingEvent?.startTime ?? '09:00';
    List<String> selectedParticipants = existingEvent != null
        ? List<String>.from(existingEvent.participantNames)
        : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = _isDarkOverride ?? (Theme.of(context).brightness == Brightness.dark);
            final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
            final textStyle = TextStyle(color: isDark ? Colors.white : Colors.black87);
            final labelStyle = GoogleFonts.notoSansKr(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            );

            return Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 10,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pull indicator
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEdit ? '일정 수정' : '새 일정 추가',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text('일정 제목', style: labelStyle),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: titleController,
                      placeholder: '예: 🍔 애월 더클리프',
                      placeholderStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                      style: textStyle,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    const SizedBox(height: 16),

                    // Detail / Memo
                    Text('상세 설명 / 메모', style: labelStyle),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: descController,
                      placeholder: '세부 메모를 적어보세요.',
                      placeholderStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                      style: textStyle,
                      maxLines: 3,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    const SizedBox(height: 16),

                    // Category
                    Text('카테고리 선택', style: labelStyle),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCategory,
                          dropdownColor: sheetBg,
                          style: textStyle,
                          isExpanded: true,
                          icon: Icon(CupertinoIcons.chevron_down, size: 16, color: isDark ? Colors.white60 : Colors.black45),
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() => selectedCategory = val);
                            }
                          },
                          items: ['관광', '식도락', '숙소', '교통', '기타']
                              .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Estimated Cost
                    Text('예상 비용 (KRW)', style: labelStyle),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: costController,
                      placeholder: '예: 25000',
                      placeholderStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                      style: textStyle,
                      keyboardType: TextInputType.number,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    const SizedBox(height: 16),

                    // Time Select
                    Text('시간 설정', style: labelStyle),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final parts = selectedTime.split(':');
                        int initHour = int.tryParse(parts[0]) ?? 9;
                        int initMin = int.tryParse(parts[1]) ?? 0;
                        final tod = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: initHour, minute: initMin),
                        );
                        if (tod != null) {
                          final hrStr = tod.hour.toString().padLeft(2, '0');
                          final mnStr = tod.minute.toString().padLeft(2, '0');
                          setSheetState(() => selectedTime = '$hrStr:$mnStr');
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(selectedTime, style: textStyle),
                            Icon(CupertinoIcons.clock, size: 18, color: isDark ? Colors.white60 : Colors.black45),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Assigned Travelers
                    Text('동행 참여자 선택', style: labelStyle),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _participants.map((p) {
                        final isSel = selectedParticipants.contains(p.name);
                        return GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              if (isSel) {
                                selectedParticipants.remove(p.name);
                              } else {
                                selectedParticipants.add(p.name);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? (isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF))
                                  : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(p.emoji, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 4),
                                Text(
                                  p.name,
                                  style: TextStyle(
                                    color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    fontSize: 13,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(10),
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              '취소',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CupertinoButton(
                            color: isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(10),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              if (titleController.text.trim().isEmpty) return;
                              final parsedCost = int.tryParse(costController.text.trim()) ?? 0;

                              if (isEdit) {
                                final updated = TravelEvent(
                                  id: existingEvent.id,
                                  title: titleController.text.trim(),
                                  startTime: selectedTime,
                                  category: selectedCategory,
                                  cost: parsedCost,
                                  status: existingEvent.status,
                                  description: descController.text.trim(),
                                  participantNames: selectedParticipants,
                                  sortOrder: existingEvent.sortOrder,
                                );
                                _updateTravelEvent(updated);
                              } else {
                                final added = TravelEvent(
                                  id: '',
                                  title: titleController.text.trim(),
                                  startTime: selectedTime,
                                  category: selectedCategory,
                                  cost: parsedCost,
                                  status: 'Todo',
                                  description: descController.text.trim(),
                                  participantNames: selectedParticipants,
                                  sortOrder: _events.length,
                                );
                                _addTravelEvent(added);
                              }
                              Navigator.pop(context);
                            },
                            child: Text(
                              isEdit ? '수정' : '저장',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Cycle Event status Todo -> In Progress -> Done
  void _cycleEventStatus(TravelEvent e) {
    String nextStatus = 'Todo';
    if (e.status == 'Todo') {
      nextStatus = 'In Progress';
    } else if (e.status == 'In Progress') {
      nextStatus = 'Done';
    } else {
      nextStatus = 'Todo';
    }

    final updated = TravelEvent(
      id: e.id,
      title: e.title,
      startTime: e.startTime,
      category: e.category,
      cost: e.cost,
      status: nextStatus,
      description: e.description,
      participantNames: e.participantNames,
      sortOrder: e.sortOrder,
    );
    _updateTravelEvent(updated);
  }

  /// Build Facepile stack for Event card
  Widget _buildFacepile(List<String> names) {
    final List<Widget> list = [];
    const double overlap = 14.0;
    final maxVisible = 3;
    final displayNames = names.take(maxVisible).toList();
    final isDark = _isDarkOverride ?? (Theme.of(context).brightness == Brightness.dark);

    for (var i = 0; i < displayNames.length; i++) {
      final name = displayNames[i];
      final matchedP = _participants.firstWhere(
        (p) => p.name == name,
        orElse: () => Participant(id: '', name: name, emoji: '👤', role: '', email: ''),
      );

      list.add(
        Positioned(
          left: i * overlap,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                width: 1.5,
              ),
            ),
            child: CircleAvatar(
              radius: 11,
              backgroundColor: _getAvatarColor(matchedP.name),
              child: Text(matchedP.emoji, style: const TextStyle(fontSize: 11)),
            ),
          ),
        ),
      );
    }

    if (names.length > maxVisible) {
      list.add(
        Positioned(
          left: maxVisible * overlap,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                width: 1.5,
              ),
            ),
            child: CircleAvatar(
              radius: 11,
              backgroundColor: Colors.grey[400],
              child: Text(
                '+${names.length - maxVisible}',
                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: (displayNames.length * overlap) + (names.length > maxVisible ? 20 : 10),
      height: 24,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: list,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkOverride ?? (Theme.of(context).brightness == Brightness.dark);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    // Apply filters to timeline events
    final filteredEvents = _events.where((e) {
      final matchesSearch = e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategoryFilter == '전체' || e.category == _selectedCategoryFilter;
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : SafeArea(
              bottom: false,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480), // Mobile frame mock
                  color: isDark ? Colors.black : const Color(0xFFF2F2F7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Premium Top Navigation Header
                      _buildHeader(isDark),

                      // Dashboard Body Scroll
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            if (!_isOffline) {
                              await _fetchPlanData();
                            }
                          },
                          color: const Color(0xFF007AFF),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            children: [
                              // 2. Trip Overview & D-Day Widget
                              _buildTripOverviewCard(isDark),
                              const SizedBox(height: 16),

                              // 4. Expense Tracker with custom doughnut chart
                              _buildExpenseWidget(cardBg, isDark),
                              const SizedBox(height: 16),

                              // 5. Timeline header filters
                              _buildTimelineFilterWidget(isDark),
                              const SizedBox(height: 8),

                              // Chronological Timeline items list
                              filteredEvents.isEmpty
                                  ? _buildEmptyTimelineState(cardBg, isDark)
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: filteredEvents.length,
                                      itemBuilder: (context, index) {
                                        return _buildTimelineItem(
                                          event: filteredEvents[index],
                                          isFirst: index == 0,
                                          isLast: index == filteredEvents.length - 1,
                                          cardBg: cardBg,
                                          isDark: isDark,
                                        );
                                      },
                                    ),
                              const SizedBox(height: 16),

                              // 6. Packing Checklist Widget
                              _buildChecklistWidget(cardBg, isDark),
                              const SizedBox(height: 16),

                              // 3. Participants Widget
                              _buildParticipantsWidget(cardBg, isDark),
                              const SizedBox(height: 48), // Padding space at bottom
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// 1. Navigation Header
  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E2E32) : const Color(0xFFF2F2F7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.chevron_back,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _planName,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '코드: $_planCode 📋',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Code copy button
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _planCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('코드가 복사되었습니다: $_planCode'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E2E32) : const Color(0xFFF2F2F7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.doc_on_doc,
                    color: isDark ? Colors.white70 : Colors.black54,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Quick Add Plan button
              GestureDetector(
                onTap: () => _showEventBottomSheet(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF007AFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.plus,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Overview & D-Day Widget
  Widget _buildTripOverviewCard(bool isDark) {
    final dDayStr = _getDDayString(_planDate);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E3C72), const Color(0xFF2A5298)] // Deep ocean blue
              : [const Color(0xFF4A90E2), const Color(0xFF50E3C2)], // Sun-kissed turquoise
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Beautiful glowing glassmorphism D-Day badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
                child: Text(
                  dDayStr,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(CupertinoIcons.paperplane_fill, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _planName,
            style: GoogleFonts.notoSansKr(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(color: Colors.black12, offset: const Offset(0, 2), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(_planDate),
            style: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Participants Widget
  Widget _buildParticipantsWidget(Color cardBg, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '함께하는 동행자',
            style: GoogleFonts.notoSansKr(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 94,
            child: _participants.isEmpty
                ? Center(
                    child: Text(
                      '등록된 동행자가 없습니다.',
                      style: GoogleFonts.notoSansKr(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _participants.length,
                    itemBuilder: (context, index) {
                      final p = _participants[index];
                      return GestureDetector(
                        onLongPress: () => _confirmDeleteParticipant(p),
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: _getAvatarColor(p.name),
                                child: Text(p.emoji, style: const TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                p.name,
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                p.role,
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 9,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 4. Expense Tracker Widget & Custom Painted Doughnut Chart
  Widget _buildExpenseWidget(Color cardBg, bool isDark) {
    final breakdown = _getCategoryBreakdown();
    final total = _getTotalExpense();
    const budget = 300000;
    final progress = total / budget;

    final categoryColors = {
      '관광': const Color(0xFF007AFF),
      '식도락': const Color(0xFFFF9500),
      '숙소': const Color(0xFFAF52DE),
      '교통': const Color(0xFF34C759),
      '기타': const Color(0xFF8E8E93),
    };

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '지출 리포트',
            style: GoogleFonts.notoSansKr(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Custom Doughnut Chart
              Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(110, 110),
                    painter: DoughnutChartPainter(
                      categoryCosts: breakdown,
                      totalCost: total,
                      isDark: isDark,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '총 지출',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatKRW(total),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 24),
              // Category legend breakdown
              Expanded(
                child: Column(
                  children: breakdown.entries.map((item) {
                    final color = categoryColors[item.key] ?? Colors.grey;
                    final pct = total > 0 ? (item.value / total) * 100 : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.key,
                            style: GoogleFonts.notoSansKr(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${pct.toStringAsFixed(0)}%',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatKRW(item.value),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Target budget progress bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '목표 예산 대비',
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% (${_formatKRW(budget)} 기준)',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: progress > 1.0 ? Colors.redAccent : const Color(0xFF007AFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress > 1.0 ? Colors.redAccent : const Color(0xFF007AFF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Timeline Filters (Segmented categories + Search)
  Widget _buildTimelineFilterWidget(bool isDark) {
    final categories = ['전체', '관광', '식도락', '숙소', '교통', '기타'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '타임라인 일정',
              style: GoogleFonts.notoSansKr(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 12),
        // Search bar
        CupertinoSearchTextField(
          placeholder: '일정 제목 또는 메모 검색',
          placeholderStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 6,
              ),
            ],
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
        ),
        const SizedBox(height: 12),
        // Category Pills
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSel = _selectedCategoryFilter == cat;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategoryFilter = cat;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel
                        ? const Color(0xFF007AFF)
                        : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      cat,
                      style: GoogleFonts.notoSansKr(
                        color: isSel ? Colors.white : (isDark ? Colors.white54 : Colors.black54),
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Empty Timeline display state
  Widget _buildEmptyTimelineState(Color cardBg, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(CupertinoIcons.calendar_badge_minus, size: 40, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(
            '해당되는 일정이 없습니다.',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Individual Timeline Event Card with Vertical Line connecting nodes
  Widget _buildTimelineItem({
    required TravelEvent event,
    required bool isFirst,
    required bool isLast,
    required Color cardBg,
    required bool isDark,
  }) {
    Color statusColor = const Color(0xFF007AFF); // Todo: iOS Blue
    if (event.status == 'In Progress') {
      statusColor = const Color(0xFFFF9500); // Orange
    } else if (event.status == 'Done') {
      statusColor = const Color(0xFF34C759); // Green
    }

    final categoryIcons = {
      '관광': '🗺️',
      '식도락': '🍔',
      '숙소': '🏨',
      '교통': '🚗',
      '기타': '🛍️',
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Side: Time (09:00)
          SizedBox(
            width: 50,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                event.startTime,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Middle Side: Vertical Connection Line + Interactive Status Circle Dot
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
                  ),
                ),
                GestureDetector(
                  onTap: () => _cycleEventStatus(event),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor.withOpacity(0.2),
                      border: Border.all(color: statusColor, width: 3),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Right Side: Card UI
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryIcons[event.category] ?? '✈️',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (event.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  event.description,
                                  style: GoogleFonts.notoSansKr(
                                    fontSize: 11,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Quick Action Buttons
                        PopupMenuButton<String>(
                          icon: Icon(CupertinoIcons.ellipsis_vertical, size: 14, color: isDark ? Colors.white38 : Colors.black38),
                          padding: EdgeInsets.zero,
                          style: ButtonStyle(
                            padding: WidgetStateProperty.all(EdgeInsets.zero),
                          ),
                          onSelected: (val) {
                            if (val == 'edit') {
                              _showEventBottomSheet(existingEvent: event);
                            } else if (val == 'delete') {
                              _deleteTravelEvent(event.id);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.pencil, size: 14),
                                  SizedBox(width: 8),
                                  Text('수정', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.trash, size: 14, color: Colors.redAccent),
                                  SizedBox(width: 8),
                                  Text('삭제', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Card Bottom: Facepile + Cost Tag + Status Pill
                    Row(
                      children: [
                        // Facepile
                        if (event.participantNames.isNotEmpty) ...[
                          _buildFacepile(event.participantNames),
                          const SizedBox(width: 12),
                        ],
                        // Cost Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatKRW(event.cost),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Status Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event.status,
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 6. Preparation Packing Checklist Helper
  Widget _buildChecklistWidget(Color cardBg, bool isDark) {
    final doneCount = _checklist.where((c) => c.checked).length;
    final totalCount = _checklist.length;
    final pct = totalCount > 0 ? doneCount / totalCount : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '준비물 체크리스트',
                style: GoogleFonts.notoSansKr(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              // Delete checked items button
              if (doneCount > 0)
                GestureDetector(
                  onTap: _deleteCheckedItems,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '선택 삭제',
                      style: GoogleFonts.notoSansKr(
                        color: Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Simple visual status bar for checklist
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '체크 비율',
                style: GoogleFonts.notoSansKr(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
              ),
              Text(
                '$doneCount/$totalCount 완료',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF007AFF)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Checklist items List
          _checklist.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      '준비물이 비어있습니다.',
                      style: GoogleFonts.notoSansKr(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _checklist.length,
                  itemBuilder: (context, index) {
                    final item = _checklist[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _toggleChecklistItem(item),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: item.checked
                                    ? const Color(0xFF007AFF)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: item.checked
                                      ? const Color(0xFF007AFF)
                                      : (isDark ? Colors.white24 : Colors.black26),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: item.checked
                                  ? const Icon(CupertinoIcons.checkmark, size: 12, color: Colors.white)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 250),
                              style: TextStyle(
                                fontSize: 13,
                                color: item.checked
                                    ? (isDark ? Colors.white38 : Colors.black38)
                                    : (isDark ? Colors.white70 : Colors.black87),
                                decoration: item.checked
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                fontWeight: item.checked ? FontWeight.normal : FontWeight.w500,
                              ),
                              child: Text(item.title),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _deleteChecklistItem(item.id),
                            child: Icon(CupertinoIcons.xmark, size: 14, color: isDark ? Colors.white24 : Colors.black26),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          const SizedBox(height: 16),
          // Add checklist item row inputs
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _checklistInputController,
                  placeholder: '예: 비상약 💊',
                  placeholderStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                color: const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(10),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onPressed: () {
                  final text = _checklistInputController.text.trim();
                  if (text.isNotEmpty) {
                    _addChecklistItem(text);
                    _checklistInputController.clear();
                  }
                },
                child: Text(
                  '등록',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const weekDays = ['일', '월', '화', '수', '목', '금', '토'];
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} (${weekDays[date.weekday % 7]})';
  }
}

/// Custom Doughnut Chart Painter for category distribution
class DoughnutChartPainter extends CustomPainter {
  final Map<String, int> categoryCosts;
  final int totalCost;
  final bool isDark;

  DoughnutChartPainter({
    required this.categoryCosts,
    required this.totalCost,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.18; // thickness

    final basePaint = Paint()
      ..color = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    if (totalCost == 0) {
      canvas.drawCircle(center, radius - strokeWidth / 2, basePaint);
      return;
    }

    final categoryColors = {
      '관광': const Color(0xFF007AFF),
      '식도락': const Color(0xFFFF9500),
      '숙소': const Color(0xFFAF52DE),
      '교통': const Color(0xFF34C759),
      '기타': const Color(0xFF8E8E93),
    };

    double startAngle = -3.1415926535 / 2; // top center start

    categoryCosts.forEach((category, cost) {
      if (cost <= 0) return;
      final sweepAngle = (cost / totalCost) * 2 * 3.1415926535;
      final paint = Paint()
        ..color = categoryColors[category] ?? const Color(0xFF8E8E93)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round; // premium rounded edge stroke

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    });
  }

  @override
  bool shouldRepaint(covariant DoughnutChartPainter oldDelegate) {
    return oldDelegate.totalCost != totalCost ||
        oldDelegate.isDark != isDark ||
        oldDelegate.categoryCosts.length != categoryCosts.length;
  }
}
