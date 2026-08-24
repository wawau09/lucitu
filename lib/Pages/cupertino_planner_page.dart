import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:placelist/models/planner_model.dart';
import 'package:placelist/widgets/track_timeline_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:placelist/utils/app_colors.dart';
import 'package:placelist/providers/stores_provider.dart';
import 'package:placelist/DB/store.dart';

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
  int _targetBudget = 300000;

  bool? _isDarkOverride;

  // Filter and Search states
  String _searchQuery = '';

  // Text controller for adding checklist items
  final TextEditingController _checklistInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTargetBudget();
    _fetchPlanData();
  }

  Future<void> _loadTargetBudget() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('target_budget_${widget.planId}');
    if (saved != null && mounted) {
      setState(() {
        _targetBudget = saved;
      });
    }
  }

  Future<void> _saveTargetBudget(int newBudget) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('target_budget_${widget.planId}', newBudget);
    if (mounted) {
      setState(() {
        _targetBudget = newBudget;
      });
    }
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

  Future<void> _saveEventsToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listMap = _events.map((e) => e.toMap()).toList();
      await prefs.setString('events_${widget.planId}', jsonEncode(listMap));
    } catch (e) {
      debugPrint('Error saving local events: $e');
    }
  }

  Future<List<TravelEvent>> _loadEventsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('events_${widget.planId}');
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(raw);
        return jsonList
            .map((e) => TravelEvent.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading local events: $e');
    }
    return [];
  }

  Future<void> _saveChecklistToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listMap = _checklist.map((c) => c.toMap()).toList();
      await prefs.setString('checklist_${widget.planId}', jsonEncode(listMap));
    } catch (e) {
      debugPrint('Error saving local checklist: $e');
    }
  }

  Future<List<ChecklistItem>> _loadChecklistFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('checklist_${widget.planId}');
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(raw);
        return jsonList
            .map((e) => ChecklistItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading local checklist: $e');
    }
    return [];
  }

  /// Sync data from Supabase
  Future<void> _fetchPlanData() async {
    // 1. SharedPreferences 로컬 캐시 먼저 로드 (실시간 UX)
    final cachedChecklist = await _loadChecklistFromLocal();
    final cachedEvents = await _loadEventsFromLocal();
    if (mounted) {
      setState(() {
        if (cachedChecklist.isNotEmpty) _checklist = cachedChecklist;
        if (cachedEvents.isNotEmpty) _events = cachedEvents;
      });
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _loadLocalMockData();
        if (cachedEvents.isNotEmpty) {
          setState(() => _events = cachedEvents);
        }
        if (cachedChecklist.isNotEmpty) {
          setState(() => _checklist = cachedChecklist);
        }
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
        if (cachedEvents.isNotEmpty) {
          setState(() => _events = cachedEvents);
        }
        if (cachedChecklist.isNotEmpty) {
          setState(() => _checklist = cachedChecklist);
        }
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

        final endTimeRaw = row['end_time']?.toString() ?? noteMap['end_time']?.toString();
        final endTime = (endTimeRaw != null && endTimeRaw.isNotEmpty) ? endTimeRaw : null;

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
            endTime: endTime,
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
        if (loadedEvents.isNotEmpty) {
          _events = loadedEvents;
          _saveEventsToLocal();
        } else if (cachedEvents.isNotEmpty) {
          _events = cachedEvents;
        }
        if (loadedChecklist.isNotEmpty) {
          _checklist = loadedChecklist;
          _saveChecklistToLocal();
        } else if (cachedChecklist.isNotEmpty) {
          _checklist = cachedChecklist;
        }
        _isOffline = false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching data: $e');
      _loadLocalMockData();
      if (cachedEvents.isNotEmpty) {
        setState(() {
          _events = cachedEvents;
        });
      }
      if (cachedChecklist.isNotEmpty) {
        setState(() {
          _checklist = cachedChecklist;
        });
      }
      setState(() => _isLoading = false);
    }
  }

  void _loadLocalMockData() {
    _planName = '우리들의 감성 제주';
    _planDate = DateTime(2026, 7, 12);
    _planCode = '1ADB';
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

  /// Add Event with Supabase Sync & Persistent Local Storage
  Future<void> _addTravelEvent(TravelEvent newEvent) async {
    final noteMap = {
      'category': newEvent.category,
      'cost': newEvent.cost,
      'status': newEvent.status,
      'description': newEvent.description,
      'participants': newEvent.participantNames,
      'end_time': newEvent.endTime,
    };

    if (!_isOffline && !widget.planId.startsWith('mock_')) {
      try {
        final row = await Supabase.instance.client.from('plan_items').insert({
          'plan_id': widget.planId,
          'title': newEvent.title,
          'start_time': newEvent.startTime,
          'note': jsonEncode(noteMap),
          'sort_order': newEvent.sortOrder,
        }).select().single();

        final createdEvent = TravelEvent(
          id: row['id']?.toString() ?? '',
          title: newEvent.title,
          startTime: newEvent.startTime,
          endTime: newEvent.endTime,
          category: newEvent.category,
          cost: newEvent.cost,
          status: newEvent.status,
          description: newEvent.description,
          participantNames: newEvent.participantNames,
          sortOrder: newEvent.sortOrder,
        );

        setState(() {
          _events.add(createdEvent);
          _events.sort((a, b) => a.startTime.compareTo(b.startTime));
        });
        await _saveEventsToLocal();
        return;
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
        endTime: event.endTime,
        category: event.category,
        cost: event.cost,
        status: event.status,
        description: event.description,
        participantNames: event.participantNames,
        sortOrder: event.sortOrder,
      ));
      _events.sort((a, b) => a.startTime.compareTo(b.startTime));
    });
    _saveEventsToLocal();
  }

  /// Update Event with Supabase Sync & Persistent Local Storage
  Future<void> _updateTravelEvent(TravelEvent updatedEvent) async {
    setState(() {
      final index = _events.indexWhere((e) => e.id == updatedEvent.id);
      if (index != -1) {
        _events[index] = updatedEvent;
        _events.sort((a, b) => a.startTime.compareTo(b.startTime));
      }
    });
    await _saveEventsToLocal();

    if (!_isOffline && !updatedEvent.id.startsWith('mock_') && !updatedEvent.id.startsWith('local_')) {
      try {
        final noteMap = {
          'category': updatedEvent.category,
          'cost': updatedEvent.cost,
          'status': updatedEvent.status,
          'description': updatedEvent.description,
          'participants': updatedEvent.participantNames,
          'end_time': updatedEvent.endTime,
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
  }

  /// Delete Event with Supabase Sync & Persistent Local Storage
  Future<void> _deleteTravelEvent(String eventId) async {
    setState(() {
      _events.removeWhere((e) => e.id == eventId);
    });
    await _saveEventsToLocal();

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
  }

  /// Add Checklist Item with Supabase Sync & Persistent Local Storage
  Future<void> _addChecklistItem(String title) async {
    final nextOrder = _checklist.length;
    final localId = 'local_c_${DateTime.now().millisecondsSinceEpoch}';
    final newItem = ChecklistItem(
      id: localId,
      title: title,
      checked: false,
      sortOrder: nextOrder,
    );

    // 1. 로컬 상태 & SharedPreferences에 영구 저장 (유실 방지)
    setState(() {
      _checklist.add(newItem);
    });
    await _saveChecklistToLocal();

    // 2. Supabase DB와 비동기 동기화
    if (!_isOffline && !widget.planId.startsWith('mock_')) {
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

        final dbId = row['id']?.toString();
        if (dbId != null && dbId.isNotEmpty) {
          final idx = _checklist.indexWhere((c) => c.id == localId);
          if (idx != -1) {
            setState(() {
              _checklist[idx] = ChecklistItem(
                id: dbId,
                title: title,
                checked: false,
                sortOrder: nextOrder,
              );
            });
            await _saveChecklistToLocal();
          }
        }
      } catch (e) {
        debugPrint('DB Checklist add error: $e');
      }
    }
  }

  /// Toggle Checklist Checked Status
  Future<void> _toggleChecklistItem(ChecklistItem item) async {
    final newChecked = !item.checked;
    setState(() {
      item.checked = newChecked;
    });
    await _saveChecklistToLocal();

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
    setState(() {
      _checklist.removeWhere((c) => c.id == id);
    });
    await _saveChecklistToLocal();

    if (!_isOffline && !id.startsWith('mock_') && !id.startsWith('local_')) {
      try {
        await Supabase.instance.client.from('plan_items').delete().eq('id', id);
      } catch (e) {
        debugPrint('DB Checklist delete error: $e');
      }
    }
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

  /// Show iOS-style wheel time picker (scroll up/down)
  Future<TimeOfDay?> _showWheelTimePicker({
    required BuildContext context,
    required TimeOfDay initialTime,
    required bool isDark,
  }) async {
    TimeOfDay selectedTime = initialTime;
    final now = DateTime.now();
    final initialDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      initialTime.hour,
      initialTime.minute,
    );

    return showCupertinoModalPopup<TimeOfDay>(
      context: context,
      builder: (BuildContext popupContext) {
        return Container(
          height: 290,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white12 : Colors.black12,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(popupContext).pop(),
                        child: Text(
                          '취소',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : CupertinoColors.systemGrey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        '시간 설정',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(popupContext).pop(selectedTime),
                        child: const Text(
                          '완료',
                          style: TextStyle(
                            color: Color(0xFF007AFF),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: false,
                    initialDateTime: initialDateTime,
                    onDateTimeChanged: (DateTime newDateTime) {
                      selectedTime = TimeOfDay(
                        hour: newDateTime.hour,
                        minute: newDateTime.minute,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Open Cupertino Modal Bottom Sheet for Add/Edit Event
  void _showEventBottomSheet({TravelEvent? existingEvent}) {
    final isEdit = existingEvent != null;
    final titleController = TextEditingController(text: existingEvent?.title ?? '');
    final costController = TextEditingController(text: existingEvent?.cost.toString() ?? '');
    String selectedStartTime = existingEvent?.startTime ?? '09:00';
    String? selectedEndTime = existingEvent?.endTime;
    bool hasEndTime = selectedEndTime != null && selectedEndTime.isNotEmpty;
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('시간 설정', style: labelStyle),
                        GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              if (hasEndTime) {
                                hasEndTime = false;
                                selectedEndTime = null;
                              } else {
                                hasEndTime = true;
                                selectedEndTime = selectedStartTime;
                              }
                            });
                          },
                          child: Text(
                            hasEndTime ? '- 종료 시간 삭제' : '+ 종료 시간 추가',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Start Time Button
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final parts = selectedStartTime.split(':');
                              int initHour = int.tryParse(parts[0]) ?? 9;
                              int initMin = int.tryParse(parts[1]) ?? 0;
                              final tod = await _showWheelTimePicker(
                                context: context,
                                initialTime: TimeOfDay(hour: initHour, minute: initMin),
                                isDark: isDark,
                              );
                              if (tod != null) {
                                final hrStr = tod.hour.toString().padLeft(2, '0');
                                final mnStr = tod.minute.toString().padLeft(2, '0');
                                setSheetState(() => selectedStartTime = '$hrStr:$mnStr');
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    hasEndTime ? '시작 $selectedStartTime' : selectedStartTime,
                                    style: textStyle,
                                  ),
                                  Icon(CupertinoIcons.clock, size: 16, color: isDark ? Colors.white60 : Colors.black45),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (hasEndTime) ...[
                          const SizedBox(width: 8),
                          // End Time Button
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final parts = (selectedEndTime ?? selectedStartTime).split(':');
                                int initHour = int.tryParse(parts[0]) ?? 10;
                                int initMin = int.tryParse(parts[1]) ?? 0;
                                final tod = await _showWheelTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(hour: initHour, minute: initMin),
                                  isDark: isDark,
                                );
                                if (tod != null) {
                                  final hrStr = tod.hour.toString().padLeft(2, '0');
                                  final mnStr = tod.minute.toString().padLeft(2, '0');
                                  setSheetState(() => selectedEndTime = '$hrStr:$mnStr');
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('종료 ${selectedEndTime ?? selectedStartTime}', style: textStyle),
                                    Icon(CupertinoIcons.clock, size: 16, color: isDark ? Colors.white60 : Colors.black45),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
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
                        if (isEdit) ...[
                          CupertinoButton(
                            color: Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            onPressed: () {
                              _deleteTravelEvent(existingEvent.id);
                              Navigator.pop(context);
                            },
                            child: const Icon(CupertinoIcons.trash, color: Colors.redAccent, size: 18),
                          ),
                          const SizedBox(width: 8),
                        ],
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
                              final finalEndTime = hasEndTime ? selectedEndTime : null;

                              if (isEdit) {
                                final updated = TravelEvent(
                                  id: existingEvent.id,
                                  title: titleController.text.trim(),
                                  startTime: selectedStartTime,
                                  endTime: finalEndTime,
                                  category: existingEvent.category,
                                  cost: parsedCost,
                                  status: existingEvent.status,
                                  description: '',
                                  participantNames: selectedParticipants,
                                  sortOrder: existingEvent.sortOrder,
                                );
                                _updateTravelEvent(updated);
                              } else {
                                final added = TravelEvent(
                                  id: '',
                                  title: titleController.text.trim(),
                                  startTime: selectedStartTime,
                                  endTime: finalEndTime,
                                  category: '일반',
                                  cost: parsedCost,
                                  status: 'Todo',
                                  description: '',
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

  String _formatTimeRange(String start, String? end) {
    if (start.isEmpty) return '시간 미정';
    if (end != null && end.isNotEmpty && end != start) {
      return '$start ~ $end';
    }
    return start;
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
      endTime: e.endTime,
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
      final matchesSearch = _searchQuery.isEmpty || e.title.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
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
                              const SizedBox(height: 12),

                              // Race-track visual timeline & Detailed Timeline Cards
                              filteredEvents.isEmpty
                                  ? _buildEmptyTimelineState(cardBg, isDark)
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        TrackTimelineWidget(
                                          events: filteredEvents,
                                          isDark: isDark,
                                          onEventTap: (event) =>
                                              _showEventBottomSheet(existingEvent: event),
                                        ),
                                        const SizedBox(height: 16),
                                        // 상세 타임라인 카드 목록
                                        ...filteredEvents.asMap().entries.map((entry) {
                                          final index = entry.key;
                                          final event = entry.value;
                                          return _buildTimelineEventCard(
                                            event: event,
                                            index: index + 1,
                                            isFirst: index == 0,
                                            isLast: index == filteredEvents.length - 1,
                                            isDark: isDark,
                                            onTap: () =>
                                                _showEventBottomSheet(existingEvent: event),
                                          );
                                        }),
                                      ],
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

  void _showEditTargetBudgetDialog() {
    final controller = TextEditingController(
        text: _targetBudget > 0 ? _targetBudget.toString() : '');
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            '목표 예산 설정',
            style: GoogleFonts.notoSansKr(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '이번 일정의 목표 지출 금액을 설정해 보세요.',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: '목표 예산 (원)',
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  hintText: '예) 300000',
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                  suffixText: '원',
                  suffixStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [100000, 200000, 300000, 500000, 1000000].map((preset) {
                  return ActionChip(
                    label: Text('${preset ~/ 10000}만원'),
                    backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                    labelStyle: TextStyle(
                      color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF007AFF),
                      fontWeight: FontWeight.w600,
                    ),
                    onPressed: () {
                      controller.text = preset.toString();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('취소', style: TextStyle(color: isDark ? Colors.white60 : Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed != null && parsed >= 0) {
                  _saveTargetBudget(parsed);
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  /// 4. Expense Tracker Widget & Custom Painted Doughnut Chart
  Widget _buildExpenseWidget(Color cardBg, bool isDark) {
    final breakdown = _getCategoryBreakdown();
    final total = _getTotalExpense();
    final budget = _targetBudget;
    final progress = budget > 0 ? total / budget : 0.0;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '지출 리포트',
                style: GoogleFonts.notoSansKr(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Flexible(
                child: InkWell(
                  onTap: _showEditTargetBudgetDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.pencil,
                          size: 12,
                          color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF007AFF),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '목표 예산: ${_formatKRW(budget)}',
                              style: GoogleFonts.notoSansKr(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF007AFF),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Custom Doughnut Chart
              Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(115, 115),
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
                      const SizedBox(height: 2),
                      SizedBox(
                        width: 72,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatKRW(total),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 20),
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
                              fontSize: 10,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          const SizedBox(width: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _formatKRW(item.value),
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
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
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${(progress * 100).toStringAsFixed(0)}% (${_formatKRW(budget)} 기준)',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: progress > 1.0 ? Colors.redAccent : const Color(0xFF007AFF),
                    ),
                  ),
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

  /// 5. Timeline Search
  Widget _buildTimelineFilterWidget(bool isDark) {
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
          ],
        ),
        const SizedBox(height: 12),
        // Search bar
        CupertinoSearchTextField(
          placeholder: '일정 제목 검색',
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

  Widget _buildTimelineEventCard({
    required TravelEvent event,
    required int index,
    required bool isFirst,
    required bool isLast,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final stores = ref.watch(storesProvider).valueOrNull ?? [];
    Store? matchingStore;
    for (final s in stores) {
      if (s.name.trim().toLowerCase() == event.title.trim().toLowerCase()) {
        matchingStore = s;
        break;
      }
    }

    final imageUrl = matchingStore?.imageUrls.isNotEmpty == true ? matchingStore!.imageUrls.first : null;
    final region = matchingStore?.region;
    final tags = (matchingStore?.categoryTags.isNotEmpty == true)
        ? matchingStore!.categoryTags.take(2).map((t) => t.startsWith('#') ? t : '#$t').toList()
        : [
            if (region != null && region.isNotEmpty) '#$region',
          ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 왼쪽 세로 라인 + 번호/시간 마커
          SizedBox(
            width: 48,
            child: Column(
              children: [
                // 상단 세로 라인
                Container(
                  width: 2,
                  height: 14,
                  color: isFirst ? Colors.transparent : (isDark ? Colors.white24 : const Color(0xFFD8D2CB)),
                ),
                // 번호 마커 원형 뱃지
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.accentLight : AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? Colors.black : AppColors.primary).withOpacity(0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.backgroundDark : Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // 시간 텍스트 (마커 아래)
                Text(
                  event.startTime,
                  style: GoogleFonts.notoSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
                // 하단 세로 라인
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : (isDark ? Colors.white24 : const Color(0xFFD8D2CB)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 2. 오른쪽 타임라인 항목 (네모 박스, 테두리, 배경 제거)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    if (imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                            ),
                            errorWidget: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // 카페명(Bold 15px) + 시간
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 카페명 (Bold 15px)
                          Text(
                            event.title,
                            style: GoogleFonts.notoSans(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // 시간 정보
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: isDark ? AppColors.accentLight : AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                event.startTime + (event.endTime != null && event.endTime!.isNotEmpty ? ' ~ ${event.endTime}' : ''),
                                style: GoogleFonts.notoSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.accentLight : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              tags.join(' '),
                              style: GoogleFonts.notoSans(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.grey[500],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // 우측 편집/상세 화살표
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: isDark ? Colors.white24 : Colors.black26,
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

  Widget _buildFallbackThumbnail(TravelEvent event, bool isDark) {
    IconData iconData = Icons.coffee_rounded;
    if (event.category == '숙소') iconData = Icons.hotel_rounded;
    if (event.category == '교통') iconData = Icons.directions_bus_rounded;
    if (event.category == '관광') iconData = Icons.photo_camera_rounded;

    return Container(
      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF4EDE6),
      child: Center(
        child: Icon(
          iconData,
          color: isDark ? Colors.white38 : AppColors.accent,
          size: 28,
        ),
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
