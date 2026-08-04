import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:placelist/DB/plan.dart';
import 'package:placelist/DB/plan_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlansNotifier extends StateNotifier<AsyncValue<List<PlanSummary>>> {
  PlansNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  final PlanDatabase _db = PlanDatabase();
  final SupabaseClient _client = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSub;

  void _init() {
    _authSub = _client.auth.onAuthStateChange.listen((data) {
      if (data.session?.user == null) {
        state = const AsyncValue.data([]);
      } else {
        refresh();
      }
    });

    if (_client.auth.currentUser == null) {
      state = const AsyncValue.data([]);
    } else {
      refresh();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final plans = await _db.getVisiblePlans();
      state = AsyncValue.data(plans);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<PlanSummary> createPlan({
    required String name,
    required DateTime planDate,
  }) async {
    final created = await _db.createPlan(name: name, planDate: planDate);
    await refresh();
    return created;
  }

  Future<void> deletePlan(String planId) async {
    await _db.deletePlan(planId);
    await refresh();
  }

  Future<PlanDetail> getPlanDetail(String planId) {
    return _db.getPlanDetail(planId);
  }

  Future<PlanSummary> joinPlanByCode({
    required String planCode,
  }) async {
    final joined = await _db.joinPlanByCode(planCode: planCode);
    await refresh();
    return joined;
  }

  Future<void> removeCollaborator({
    required String planId,
    required String email,
  }) async {
    await _db.removeCollaborator(planId: planId, email: email);
    await refresh();
  }

  Future<void> addPlanItem({
    required String planId,
    required PlanDraft draft,
  }) async {
    await _db.addPlanItem(planId: planId, draft: draft);
    await refresh();
  }

  Future<void> deletePlanItem(String itemId) async {
    await _db.deletePlanItem(itemId);
    await refresh();
  }

  Future<void> updatePlanItem({
    required String itemId,
    required PlanDraft draft,
  }) async {
    await _db.updatePlanItem(itemId: itemId, draft: draft);
    await refresh();
  }
}

final plansProvider =
    StateNotifierProvider<PlansNotifier, AsyncValue<List<PlanSummary>>>((ref) {
  return PlansNotifier();
});

final selectedPlanIdProvider = StateProvider<String?>((ref) => null);

final selectedPlanDetailProvider =
    FutureProvider.family<PlanDetail, String>((ref, planId) async {
  final db = PlanDatabase();
  return db.getPlanDetail(planId);
});

