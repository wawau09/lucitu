import 'package:placelist/DB/plan.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlanDatabase {
  PlanDatabase() : _client = Supabase.instance.client;

  final SupabaseClient _client;
  final String _plansTable = 'plans';
  final String _collaboratorsTable = 'plan_collaborators';
  final String _itemsTable = 'plan_items';

  User? get _user => _client.auth.currentUser;

  Future<List<PlanSummary>> getVisiblePlans() async {
    final user = _user;
    if (user == null) return [];

    final email = user.email?.toLowerCase();
    
    // 1. Get plan IDs where the user is a collaborator
    List<String> collaboratorPlanIds = [];
    if (email != null && email.isNotEmpty) {
      final collabs = await _client
          .from(_collaboratorsTable)
          .select('plan_id')
          .eq('collaborator_email', email);
      collaboratorPlanIds = collabs.map((row) => row['plan_id'] as String).toList();
    }

    // 2. Fetch plans where user is owner
    final ownerRows = await _client
        .from(_plansTable)
        .select('id,name,plan_date,plan_code,owner_id,item_count,created_at,updated_at')
        .eq('owner_id', user.id);

    // 3. Fetch plans where user is collaborator
    List<dynamic> collabRows = [];
    if (collaboratorPlanIds.isNotEmpty) {
      collabRows = await _client
          .from(_plansTable)
          .select('id,name,plan_date,plan_code,owner_id,item_count,created_at,updated_at')
          .inFilter('id', collaboratorPlanIds);
    }

    // 4. Combine and deduplicate
    final Map<String, Map<String, dynamic>> allRows = {};
    for (final row in [...ownerRows, ...collabRows]) {
      final mapRow = Map<String, dynamic>.from(row as Map);
      allRows[mapRow['id'].toString()] = mapRow;
    }

    final combinedList = allRows.values.toList();
    
    // 5. Sort by updated_at descending
    combinedList.sort((a, b) {
      final dateA = DateTime.tryParse(a['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = DateTime.tryParse(b['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });

    // 6. Fetch owner names from profiles table
    final ownerIds = combinedList.map((row) => row['owner_id'] as String).toSet().toList();
    if (ownerIds.isNotEmpty) {
      try {
        final profiles = await _client.from('profiles').select('id, full_name').inFilter('id', ownerIds);
        final profileMap = {for (var p in profiles) p['id'] as String: p['full_name'] as String?};
        for (var row in combinedList) {
          row['owner_name'] = profileMap[row['owner_id']];
        }
      } catch (e) {
        // If profiles table doesn't exist yet, ignore
      }
    }

    return combinedList
        .map((row) => PlanSummary.fromMap(
              row,
              currentUserId: user.id,
            ))
        .toList();
  }

  Future<PlanDetail> getPlanDetail(String planId) async {
    final user = _user;
    if (user == null) {
      throw const PostgrestException(message: 'loginRequired');
    }

    final planRow = await _client
        .from(_plansTable)
        .select('id,name,plan_date,plan_code,owner_id,item_count,created_at,updated_at')
        .eq('id', planId)
        .maybeSingle();

    if (planRow == null) {
      throw const PostgrestException(message: 'planNotFound');
    }

    try {
      final profile = await _client.from('profiles').select('full_name, email').eq('id', planRow['owner_id']).maybeSingle();
      if (profile != null) {
        planRow['owner_name'] = profile['full_name'];
        planRow['owner_email'] = profile['email'];
      }
    } catch (e) {
      // Ignore if profiles table is missing
    }

    final plan = PlanSummary.fromMap(
      Map<String, dynamic>.from(planRow as Map),
      currentUserId: user.id,
    );

    final collaboratorRows = await _client
        .from(_collaboratorsTable)
        .select('collaborator_email,role,created_at')
        .eq('plan_id', planId)
        .order('created_at');

    final itemRows = await _client
        .from(_itemsTable)
        .select()
        .eq('plan_id', planId);

    // Fetch collaborator names
    final emails = collaboratorRows.map((r) => r['collaborator_email'] as String).toList();
    if (emails.isNotEmpty) {
      try {
        final profiles = await _client.from('profiles').select('email, full_name').inFilter('email', emails);
        final profileMap = {for (var p in profiles) p['email'] as String: p['full_name'] as String?};
        for (var row in collaboratorRows) {
          row['collaborator_name'] = profileMap[row['collaborator_email']];
        }
      } catch (e) {
        // Ignore if profiles table is missing
      }
    }

    final currentEmail = user.email?.toLowerCase();

    final ownerEmail = planRow['owner_email']?.toString() ?? '';
    final ownerName = planRow['owner_name']?.toString() ?? '만든 사람';

    final allCollaborators = [
      PlanCollaborator(
        email: ownerEmail,
        name: ownerName,
        role: 'owner',
        createdAt: DateTime.tryParse(planRow['created_at']?.toString() ?? '') ?? DateTime.now(),
        isSelf: currentEmail != null && ownerEmail.toLowerCase() == currentEmail,
      ),
      ...collaboratorRows.map(
        (row) => PlanCollaborator.fromMap(
          Map<String, dynamic>.from(row as Map),
          currentEmail: currentEmail,
        ),
      ),
    ];

    return PlanDetail(
      plan: plan,
      collaborators: allCollaborators,
      items: itemRows
          .map((row) => PlanItem.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList(),
    );
  }

  Future<PlanSummary> createPlan({
    required String name,
    required DateTime planDate,
  }) async {
    final user = _user;
    if (user == null) {
      throw const PostgrestException(message: 'loginRequired');
    }

    final row = await _client.rpc(
      'create_plan_entry',
      params: {
        'p_name': name.trim(),
        'p_plan_date': _dateString(planDate),
      },
    );

    return PlanSummary.fromMap(
      Map<String, dynamic>.from(row as Map),
      currentUserId: user.id,
    );
  }

  Future<void> deletePlan(String planId) async {
    final user = _user;
    if (user == null) {
      throw const PostgrestException(message: 'loginRequired');
    }

    await _client.from(_plansTable).delete().eq('id', planId);
  }

  Future<PlanItem> addPlanItem({
    required String planId,
    required PlanDraft draft,
  }) async {
    final user = _user;
    if (user == null) {
      throw const PostgrestException(message: 'loginRequired');
    }

    final nextOrder = await _nextSortOrder(planId);
    final startTime = draft.startTime?.trim();
    final row = await _client
        .from(_itemsTable)
        .insert({
          'plan_id': planId,
          'title': draft.title.trim(),
          'start_time': startTime == null || startTime.isEmpty ? null : startTime,
          'sort_order': nextOrder,
        })
        .select('id,plan_id,title,start_time,sort_order')
        .single();

    return PlanItem.fromMap(Map<String, dynamic>.from(row as Map));
  }

  Future<void> deletePlanItem(String itemId) async {
    final user = _user;
    if (user == null) {
      throw const PostgrestException(message: 'loginRequired');
    }

    await _client.from(_itemsTable).delete().eq('id', itemId);
  }

  Future<PlanSummary> joinPlanByCode({
    required String planCode,
  }) async {
    final user = _user;
    if (user == null) {
      throw const PostgrestException(message: 'loginRequired');
    }

    final row = await _client.rpc(
      'join_plan_by_code',
      params: {
        'p_plan_code': planCode.trim(),
      },
    );

    return PlanSummary.fromMap(
      Map<String, dynamic>.from(row as Map),
      currentUserId: user.id,
    );
  }

  Future<void> removeCollaborator({
    required String planId,
    required String email,
  }) async {
    final user = _user;
    if (user == null) {
      throw const PostgrestException(message: 'loginRequired');
    }

    await _client
        .from(_collaboratorsTable)
        .delete()
        .eq('plan_id', planId)
        .eq('collaborator_email', email.trim().toLowerCase());
  }

  Future<int> _nextSortOrder(String planId) async {
    final rows = await _client
        .from(_itemsTable)
        .select('sort_order')
        .eq('plan_id', planId)
        .order('sort_order', ascending: false)
        .limit(1);

    if (rows.isEmpty) return 0;
    final value = rows.first['sort_order'];
    final current = value is num
        ? (value as num).toInt()
        : int.tryParse(value?.toString() ?? '');
    return (current ?? -1) + 1;
  }

  String _dateString(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
