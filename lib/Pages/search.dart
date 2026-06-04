import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/plan.dart';
import 'package:placelist/providers/navigation_provider.dart';
import 'package:placelist/providers/plans_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:placelist/widgets/clock_schedule.dart';

class PlanPage extends ConsumerStatefulWidget {
  const PlanPage({super.key});

  @override
  ConsumerState<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends ConsumerState<PlanPage> {
  final SupabaseClient _client = Supabase.instance.client;
  String? _selectedPlanId;
  Future<PlanDetail>? _selectedPlanFuture;
  bool _queuedInitialSelection = false;

  @override
  Widget build(BuildContext context) {
    final user = _client.auth.currentUser;
    final plansAsync = ref.watch(plansProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '내 일정',
                    style: GoogleFonts.notoSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.black87),
                        onPressed: () =>
                            ref.read(plansProvider.notifier).refresh(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.black87),
                        onPressed: _showPlanActionChooser,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Expanded(
              child: plansAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => _buildErrorState(err.toString()),
                data: (plans) {
                  if (user == null) {
                    return _buildLoggedOutState();
                  }

                  if (plans.isEmpty) {
                    return _buildEmptyPlansCard();
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref.read(plansProvider.notifier).refresh(),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: plans.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Color(0xFFEEEEEE),
                      ),
                      itemBuilder: (context, index) {
                        return _buildPlanCard(plan: plans[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedOutState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note_outlined, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            "일정을 보려면 로그인이 필요합니다.",
            style: GoogleFonts.notoSans(color: Colors.grey, fontSize: 15),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(navigationProvider.notifier).setIndex(2),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
            ),
            child: const Text('로그인 하러 가기'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '\uC77C\uC815\uC744 \uBD88\uB7EC\uC624\uB294 \uC911 \uC624\uB958\uAC00 \uBC1C\uC0DD\uD588\uC2B5\uB2C8\uB2E4.\n$message',
          style: GoogleFonts.notoSans(color: Colors.black87, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildEmptyPlansCard() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_outlined, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            "아직 등록된 일정이 없네요!",
            style: GoogleFonts.notoSans(color: Colors.grey, fontSize: 15),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _showCreatePlanDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
            ),
            child: const Text('새 일정 만들기'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({required PlanSummary plan}) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlanDetailPage(planId: plan.id)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 100,
                height: 100,
                color: Colors.grey[100],
                child: Icon(
                  Icons.event_note,
                  size: 40,
                  color: Colors.grey[400],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan.name,
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (plan.sharedWithMe)
                          _buildPill(
                            label: '공유중',
                            background: const Color(0xFFF0F6FF),
                            foreground: const Color(0xFF2F5E8F),
                          )
                        else
                          _buildPill(
                            label: '내 일정',
                            background: const Color(0xFFF5F7FB),
                            foreground: const Color(0xFF374151),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.grey[600],
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatDate(plan.planDate),
                            style: GoogleFonts.notoSans(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          '코드: ${plan.planCode}',
                          style: GoogleFonts.notoSans(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (plan.isOwner)
                          IconButton(
                            onPressed: () => _confirmDeletePlan(plan),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.grey,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        else
                          const SizedBox(height: 20),
                      ],
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

  Widget _buildPill({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E1D9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF3267A2)),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: GoogleFonts.notoSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPlanDetail() {
    if (_selectedPlanId == null) {
      return const SizedBox.shrink();
    }

    final future = _selectedPlanFuture;
    if (future == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<PlanDetail>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: _detailDecoration(),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: _detailDecoration(),
            child: Text(
              '\uC120\uD0DD\uD55C \uC77C\uC815\uC744 \uBD88\uB7EC\uC624\uC9C0 \uBABB\uD588\uC2B5\uB2C8\uB2E4.',
              style: GoogleFonts.notoSans(color: Colors.black87),
            ),
          );
        }

        final detail = snapshot.data!;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: _detailDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.plan.name,
                          style: GoogleFonts.notoSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDate(detail.plan.planDate),
                          style: GoogleFonts.notoSans(
                            fontSize: 13,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: detail.plan.planCode),
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '\uC77C\uC815 \uCF54\uB4DC\uAC00 \uBCF5\uC0AC\uB418\uC5C8\uC2B5\uB2C8\uB2E4.',
                            style: GoogleFonts.notoSans(),
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    tooltip: '\uCF54\uB4DC \uBCF5\uC0AC',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPill(
                    label: detail.plan.planCode,
                    background: const Color(0xFFF8FAFC),
                    foreground: const Color(0xFF374151),
                  ),
                  _buildPill(
                    label: detail.plan.isOwner
                        ? '\uC18C\uC720\uC790'
                        : '\uACF5\uC720 \uCC38\uC5EC\uC790',
                    background: detail.plan.isOwner
                        ? const Color(0xFFF5F7FB)
                        : const Color(0xFFF0F6FF),
                    foreground: detail.plan.isOwner
                        ? const Color(0xFF374151)
                        : const Color(0xFF2F5E8F),
                  ),
                  _buildPill(
                    label: '\uD56D\uBAA9 ${detail.items.length}\uAC1C',
                    background: const Color(0xFFF5F7FB),
                    foreground: const Color(0xFF374151),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddItemDialog(detail.plan.id),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        '\uD56D\uBAA9 \uCD94\uAC00',
                        style: GoogleFonts.notoSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3267A2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showJoinByCodeDialog(),
                      icon: const Icon(Icons.group_add_rounded, size: 18),
                      label: Text(
                        '\uCF54\uB4DC\uB85C \uCC38\uAC00',
                        style: GoogleFonts.notoSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3267A2),
                        side: const BorderSide(color: Color(0xFF3267A2)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildDetailSection(
                title: '\uC77C\uC815',
                child: detail.items.isEmpty
                    ? _buildDetailEmptyState(
                        icon: Icons.calendar_today_outlined,
                        message:
                            '\uC544\uC9C1 \uC77C\uC815 \uD56D\uBAA9\uC774 \uC5C6\uC5B4\uC694.',
                      )
                    : Column(
                        children: detail.items
                            .map(
                              (item) => _buildScheduleRow(
                                item,
                                onDelete: () =>
                                    _confirmDeleteItem(detail.plan.id, item),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 14),
              _buildDetailSection(
                title: '\uC2DC\uAC04\uBCC4',
                child: detail.items.isEmpty
                    ? _buildDetailEmptyState(
                        icon: Icons.schedule_outlined,
                        message:
                            '\uC2DC\uAC04 \uAE30\uBC18 \uC77C\uC815\uC774 \uC544\uC9C1 \uC5C6\uC5B4\uC694.',
                      )
                    : ClockScheduleWidget(
                        items: detail.items,
                        onItemTap: (item) {
                          _showItemDetails(item, detail.plan.id);
                        },
                      ),
              ),
              const SizedBox(height: 14),
              _buildDetailSection(
                title: '\uACF5\uB3D9 \uC791\uC5C5\uC790',
                child: _buildCollaboratorSection(detail),
              ),
              if (detail.plan.isOwner) ...[
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () => _confirmDeletePlan(detail.plan),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(
                    '\uC774 \uC77C\uC815 \uC0AD\uC81C',
                    style: GoogleFonts.notoSans(fontWeight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB45309),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  BoxDecoration _detailDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE8E1D9)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildDetailSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFCFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9E2D9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.notoSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailEmptyState({
    required IconData icon,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E1D9)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFB3B9C4)),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.notoSans(
              fontSize: 13,
              color: const Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(PlanItem item, {required VoidCallback onDelete}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8E1D9)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Text(
                _formatItemTime(item.startTime),
                style: GoogleFonts.notoSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF3267A2),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF3267A2),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.notoSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  if ((item.note ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.note!,
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: const Color(0xFF8A8F98),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: const Color(0xFFB45309),
              tooltip: '\uC0AD\uC81C',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow(PlanItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              _formatItemTime(item.startTime),
              style: GoogleFonts.notoSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF3267A2),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF3267A2),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE8E1D9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaboratorSection(PlanDetail detail) {
    if (detail.plan.isOwner) {
      if (detail.collaborators.isEmpty) {
        return _buildDetailEmptyState(
          icon: Icons.group_outlined,
          message:
              '\uC544\uC9C1 \uB4F1\uB85D\uB41C \uACF5\uB3D9 \uC791\uC5C5\uC790\uAC00 \uC5C6\uC5B4\uC694.',
        );
      }

      return Column(
        children: detail.collaborators
            .map(
              (member) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE8E1D9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF3267A2),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          member.email,
                          style: GoogleFonts.notoSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: member.isSelf
                            ? null
                            : () => _confirmRemoveCollaborator(
                                detail.plan.id,
                                member.email,
                              ),
                        child: Text(
                          member.isSelf ? '\uB098' : '\uC0AD\uC81C',
                          style: GoogleFonts.notoSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    if (detail.collaborators.any((member) => member.isSelf)) {
      return _buildDetailEmptyState(
        icon: Icons.group_rounded,
        message:
            '\uC774 \uC77C\uC815\uC5D0 \uACF5\uC720 \uCC38\uC5EC \uC911\uC785\uB2C8\uB2E4.',
      );
    }

    return _buildDetailEmptyState(
      icon: Icons.group_outlined,
      message:
          '\uACF5\uB3D9 \uC791\uC5C5\uC790 \uC815\uBCF4\uB97C \uBCFC \uC218 \uC5C6\uC5B4\uC694.',
    );
  }

  void _syncInitialSelection(List<PlanSummary> plans) {
    if (_queuedInitialSelection || plans.isEmpty) return;
    if (_selectedPlanId != null) return;

    _queuedInitialSelection = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedPlanId == null && plans.isNotEmpty) {
        setState(() {
          _selectedPlanId = plans.first.id;
          _selectedPlanFuture = ref
              .read(plansProvider.notifier)
              .getPlanDetail(plans.first.id);
        });
      }
      _queuedInitialSelection = false;
    });
  }

  void _showPlanActionChooser() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '일정 추가',
                  style: GoogleFonts.notoSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Color(0xFF3267A2),
                    ),
                  ),
                  title: Text(
                    '새 일정 만들기',
                    style: GoogleFonts.notoSans(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '새로운 일정을 직접 생성합니다',
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreatePlanDialog();
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.group_add_rounded,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  title: Text(
                    '코드로 참가',
                    style: GoogleFonts.notoSans(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '공유받은 일정 코드를 입력하여 참가합니다',
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showJoinByCodeDialog();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreatePlanDialog() async {
    final nameController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                '\uC0C8 \uC77C\uC815 \uB9CC\uB4E4\uAE30',
                style: GoogleFonts.notoSans(fontWeight: FontWeight.w800),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '\uACC4\uD68D \uC774\uB984',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatDate(selectedDate),
                            style: GoogleFonts.notoSans(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 3650),
                              ),
                            );
                            if (picked == null) return;
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          },
                          child: const Text('\uB0A0\uC9DC \uC120\uD0DD'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('\uCDE8\uC18C'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3267A2),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('\uC0DD\uC131'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) {
      nameController.dispose();
      return;
    }

    final name = nameController.text.trim();
    nameController.dispose();
    if (name.isEmpty) return;

    try {
      final created = await ref
          .read(plansProvider.notifier)
          .createPlan(name: name, planDate: selectedDate);
      if (!mounted) return;
      setState(() {
        _selectedPlanId = created.id;
        _selectedPlanFuture = ref
            .read(plansProvider.notifier)
            .getPlanDetail(created.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\uC77C\uC815\uC774 \uC0DD\uC131\uB418\uC5C8\uC2B5\uB2C8\uB2E4.',
            style: GoogleFonts.notoSans(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\uC77C\uC815 \uC0DD\uC131 \uC2E4\uD328: $e')),
      );
    }
  }

  Future<void> _showAddItemDialog(String planId, {TimeOfDay? initialTime}) async {
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    TimeOfDay? selectedStartTime = initialTime;
    TimeOfDay? selectedEndTime;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  20,
                  24,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '\uD56D\uBAA9 \uCD94\uAC00',
                        style: GoogleFonts.notoSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: '\uC77C\uC815\uBA85',
                          hintText: '\uC77C\uC815 \uC774\uB984\uC744 \uC785\uB825\uD558\uC138\uC694',
                          prefixIcon: Icon(Icons.event_note_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Start time row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 18, color: Color(0xFF3267A2)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedStartTime == null
                                    ? '\uC2DC\uC791 \uC2DC\uAC04'
                                    : _formatTimeOfDay(selectedStartTime!),
                                style: GoogleFonts.notoSans(
                                  fontSize: 14,
                                  color: selectedStartTime == null
                                      ? Colors.grey
                                      : const Color(0xFF111827),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: sheetContext,
                                  initialTime: selectedStartTime ?? TimeOfDay.now(),
                                );
                                if (picked == null) return;
                                setDialogState(() {
                                  selectedStartTime = picked;
                                });
                              },
                              child: Text(
                                selectedStartTime == null ? '\uC120\uD0DD' : '\uBCC0\uACBD',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // End time row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_filled, size: 18, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedEndTime == null
                                    ? '\uC885\uB8CC \uC2DC\uAC04'
                                    : _formatTimeOfDay(selectedEndTime!),
                                style: GoogleFonts.notoSans(
                                  fontSize: 14,
                                  color: selectedEndTime == null
                                      ? Colors.grey
                                      : const Color(0xFF111827),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: sheetContext,
                                  initialTime: selectedEndTime ?? selectedStartTime ?? TimeOfDay.now(),
                                );
                                if (picked == null) return;
                                setDialogState(() {
                                  selectedEndTime = picked;
                                });
                              },
                              child: Text(
                                selectedEndTime == null ? '\uC120\uD0DD' : '\uBCC0\uACBD',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(sheetContext).pop(false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                                side: BorderSide(color: Colors.grey.shade300),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('\uCDE8\uC18C'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.of(sheetContext).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3267A2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: const Text('\uC800\uC7A5'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != true || !mounted) {
      titleController.dispose();
      noteController.dispose();
      return;
    }

    final title = titleController.text.trim();
    if (title.isEmpty) {
      titleController.dispose();
      noteController.dispose();
      return;
    }

    try {
      await ref
          .read(plansProvider.notifier)
          .addPlanItem(
            planId: planId,
            draft: PlanDraft(
              title: title,
              note: noteController.text.trim(),
              startTime: selectedStartTime == null
                  ? null
                  : _formatTimeOfDay(selectedStartTime!),
              endTime: selectedEndTime == null
                  ? null
                  : _formatTimeOfDay(selectedEndTime!),
            ),
          );
      _reloadSelectedPlan(planId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\uD56D\uBAA9\uC774 \uCD94\uAC00\uB418\uC5C8\uC2B5\uB2C8\uB2E4.',
            style: GoogleFonts.notoSans(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\uD56D\uBAA9 \uCD94\uAC00 \uC2E4\uD328: $e')),
      );
    } finally {
      titleController.dispose();
      noteController.dispose();
      return;}
  }

  void _showItemDetails(PlanItem item, String planId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.startTime != null)
                Text(
                  '시간: ${_formatItemTime(item.startTime)}' +
                      (item.endTime != null ? ' ~ ${_formatItemTime(item.endTime)}' : ''),
                  style: const TextStyle(fontSize: 14),
                ),
              if (item.note != null && item.note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('메모: ${item.note}', style: const TextStyle(fontSize: 14)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmDeleteItem(planId, item);
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showJoinByCodeDialog() async {
    final codeController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            '\uCF54\uB4DC\uB85C \uCC38\uAC00',
            style: GoogleFonts.notoSans(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: '\uC77C\uC815 \uCF54\uB4DC',
                    hintText: 'PL-260603-ABCD',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 10),
                Text(
                  '\uC77C\uC815 \uCF54\uB4DC\uB97C \uC785\uB825\uD558\uBA74 \uD604\uC7AC \uB85C\uADF8\uC778 \uACC4\uC815\uC774 \uACF5\uB3D9 \uC791\uC5C5\uC790\uB85C \uCD94\uAC00\uB429\uB2C8\uB2E4.',
                  style: GoogleFonts.notoSans(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('\uCDE8\uC18C'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3267A2),
                foregroundColor: Colors.white,
              ),
              child: const Text('\uCC38\uAC00'),
            ),
          ],
        );
      },
    );

    if (result != true || !mounted) {
      codeController.dispose();
      return;
    }

    final planCode = codeController.text.trim();
    codeController.dispose();
    if (planCode.isEmpty) return;

    try {
      await ref.read(plansProvider.notifier).joinPlanByCode(planCode: planCode);
      await ref.read(plansProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\uC77C\uC815\uC5D0 \uCC38\uAC00\uD588\uC2B5\uB2C8\uB2E4.',
            style: GoogleFonts.notoSans(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('\uCC38\uAC00 \uC2E4\uD328: $e')));
    }
  }

  Future<void> _confirmDeletePlan(PlanSummary plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            '\uC77C\uC815 \uC0AD\uC81C',
            style: GoogleFonts.notoSans(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '\u201C${plan.name}\u201D\uC744 \uC0AD\uC81C\uD560\uAE4C\uC694?',
            style: GoogleFonts.notoSans(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('\uCDE8\uC18C'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB45309),
                foregroundColor: Colors.white,
              ),
              child: const Text('\uC0AD\uC81C'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await ref.read(plansProvider.notifier).deletePlan(plan.id);
      if (_selectedPlanId == plan.id) {
        setState(() {
          _selectedPlanId = null;
          _selectedPlanFuture = null;
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\uC77C\uC815\uC774 \uC0AD\uC81C\uB418\uC5C8\uC2B5\uB2C8\uB2E4.',
            style: GoogleFonts.notoSans(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\uC77C\uC815 \uC0AD\uC81C \uC2E4\uD328: $e')),
      );
    }
  }

  Future<void> _confirmDeleteItem(String planId, PlanItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            '\uD56D\uBAA9 \uC0AD\uC81C',
            style: GoogleFonts.notoSans(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '\u201C${item.title}\u201D\uC744 \uC0AD\uC81C\uD560\uAE4C\uC694?',
            style: GoogleFonts.notoSans(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('\uCDE8\uC18C'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB45309),
                foregroundColor: Colors.white,
              ),
              child: const Text('\uC0AD\uC81C'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await ref.read(plansProvider.notifier).deletePlanItem(item.id);
      _reloadSelectedPlan(planId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\uD56D\uBAA9\uC774 \uC0AD\uC81C\uB418\uC5C8\uC2B5\uB2C8\uB2E4.',
            style: GoogleFonts.notoSans(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\uD56D\uBAA9 \uC0AD\uC81C \uC2E4\uD328: $e')),
      );
    }
  }

  Future<void> _confirmRemoveCollaborator(String planId, String email) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            '\uACF5\uB3D9 \uC791\uC5C5\uC790 \uC0AD\uC81C',
            style: GoogleFonts.notoSans(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '\u201C$email\u201D\uC744 \uBCF5\uC815\uD560\uAE4C\uC694?',
            style: GoogleFonts.notoSans(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('\uCDE8\uC18C'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB45309),
                foregroundColor: Colors.white,
              ),
              child: const Text('\uC0AD\uC81C'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await ref
          .read(plansProvider.notifier)
          .removeCollaborator(planId: planId, email: email);
      _reloadSelectedPlan(planId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\uACF5\uB3D9 \uC791\uC5C5\uC790\uAC00 \uC81C\uAC70\uB418\uC5C8\uC2B5\uB2C8\uB2E4.',
            style: GoogleFonts.notoSans(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('\uC0AD\uC81C \uC2E4\uD328: $e')));
    }
  }

  void _reloadSelectedPlan(String planId) {
    setState(() {
      _selectedPlanFuture = ref
          .read(plansProvider.notifier)
          .getPlanDetail(planId);
    });
  }

  String _formatDate(DateTime date) {
    const weekDays = [
      '\uC77C',
      '\uC6D4',
      '\uD654',
      '\uC218',
      '\uBAA9',
      '\uAE08',
      '\uD1A0',
    ];
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} (${weekDays[date.weekday % 7]})';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatItemTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '\uC2DC\uAC04 \uBBF8\uC815';
    if (raw.length >= 5) return raw.substring(0, 5);
    return raw;
  }
}

class PlanDetailPage extends ConsumerStatefulWidget {
  const PlanDetailPage({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends ConsumerState<PlanDetailPage> {
  Future<PlanDetail>? _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = ref
        .read(plansProvider.notifier)
        .getPlanDetail(widget.planId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlanDetail>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFFF6F5F2),
            appBar: AppBar(
              backgroundColor: const Color(0xFFF6F5F2),
              foregroundColor: const Color(0xFF111827),
              elevation: 0,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            backgroundColor: const Color(0xFFF6F5F2),
            appBar: AppBar(
              backgroundColor: const Color(0xFFF6F5F2),
              foregroundColor: const Color(0xFF111827),
              elevation: 0,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '\uC77C\uC815\uC744 \uBD88\uB7EC\uC624\uC9C0 \uBABB\uD588\uC2B5\uB2C8\uB2E4.',
                  style: GoogleFonts.notoSans(color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final detail = snapshot.data!;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F5F2),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF6F5F2),
            foregroundColor: const Color(0xFF111827),
            elevation: 0,
            title: Text(
              detail.plan.name,
              style: GoogleFonts.notoSans(fontWeight: FontWeight.w800),
            ),
          ),
          body: RefreshIndicator(
            onRefresh: _refreshPlan,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddItemDialog(detail.plan.id),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(
                            '항목 추가',
                            style: GoogleFonts.notoSans(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3267A2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: detail.plan.planCode),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '코드가 복사되었습니다: ${detail.plan.planCode}',
                                  style: GoogleFonts.notoSans(),
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: Text(
                            '코드 복사',
                            style: GoogleFonts.notoSans(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF3267A2),
                            side: const BorderSide(color: Color(0xFF3267A2)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildHorizontalTimelineBar(detail),
                  const SizedBox(height: 14),
                  _buildDetailSection(
                    title: '\uACF5\uB3D9 \uC791\uC5C5\uC790',
                    child: _buildCollaboratorSection(detail),
                  ),
                  if (detail.plan.isOwner) ...[
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: () => _confirmDeletePlan(detail.plan),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(
                        '\uC774 \uC77C\uC815 \uC0AD\uC81C',
                        style: GoogleFonts.notoSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB45309),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPill({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  BoxDecoration _detailDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE8E1D9)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildHorizontalTimelineBar(PlanDetail detail) {
    // Generate hours from 06:00 to 24:00
    final hours = List.generate(19, (index) => index + 6); // 6 to 24

    return _buildDetailSection(
      title: '\uD0C0\uC784\uB77C\uC778',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: hours.map((hour) {
          final timeString = '${hour.toString().padLeft(2, '0')}:00';

          // Find items for this hour
          final itemsInHour = detail.items.where((item) {
            if (item.startTime == null || item.startTime!.isEmpty) return false;
            final parts = item.startTime!.split(':');
            if (parts.isNotEmpty) {
              final itemHour = int.tryParse(parts[0]);
              return itemHour == hour;
            }
            return false;
          }).toList();

          return InkWell(
            onTap: () {
              _showAddItemDialog(
                detail.plan.id,
                initialTime: TimeOfDay(hour: hour, minute: 0),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time
                  SizedBox(
                    width: 48,
                    child: Text(
                      timeString,
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6B7280),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Clock icon instead of circle dot
                  Icon(
                    itemsInHour.isNotEmpty
                        ? Icons.schedule
                        : Icons.schedule_outlined,
                    size: 16,
                    color: itemsInHour.isNotEmpty
                        ? const Color(0xFF3267A2)
                        : const Color(0xFFD1D5DB),
                  ),
                  const SizedBox(width: 12),
                  // Items
                  Expanded(
                    child: itemsInHour.isEmpty
                        ? Container(
                            height: 28,
                            alignment: Alignment.centerLeft,
                            child: Icon(
                              Icons.add,
                              color: Colors.grey[300],
                              size: 18,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: itemsInHour.map((item) {
                              return Stack(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0F6FF),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFBFDBFE),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: GoogleFonts.notoSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF1E3A8A),
                                            ),
                                          ),
                                        ),
                                        if (item.endTime != null && item.endTime!.isNotEmpty)
                                          Text(
                                            '~ ${item.endTime}',
                                            style: GoogleFonts.notoSans(
                                              fontSize: 11,
                                              color: const Color(0xFF6B7280),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Color(0xFF1E3A8A),
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _confirmDeleteItem(
                                        detail.plan.id,
                                        item,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFCFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9E2D9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.notoSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailEmptyState({
    required IconData icon,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E1D9)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFB3B9C4)),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.notoSans(
              fontSize: 13,
              color: const Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(PlanItem item, {required VoidCallback onDelete}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8E1D9)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Text(
                _formatItemTime(item.startTime),
                style: GoogleFonts.notoSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF3267A2),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF3267A2),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.notoSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  if ((item.note ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.note!,
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: const Color(0xFF8A8F98),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: const Color(0xFFB45309),
              tooltip: '\uC0AD\uC81C',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceChip(String place) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E1D9)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_rounded,
            size: 18,
            color: Color(0xFF3267A2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              place,
              style: GoogleFonts.notoSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(PlanItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              _formatItemTime(item.startTime),
              style: GoogleFonts.notoSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF3267A2),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF3267A2),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE8E1D9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaboratorSection(PlanDetail detail) {
    if (detail.plan.isOwner) {
      if (detail.collaborators.isEmpty) {
        return _buildDetailEmptyState(
          icon: Icons.group_outlined,
          message:
              '\uC544\uC9C1 \uB4F1\uB85D\uB41C \uACF5\uB3D9 \uC791\uC5C5\uC790\uAC00 \uC5C6\uC5B4\uC694.',
        );
      }

      return Column(
        children: detail.collaborators
            .map(
              (member) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE8E1D9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF3267A2),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          member.email,
                          style: GoogleFonts.notoSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: member.isSelf
                            ? null
                            : () => _confirmRemoveCollaborator(
                                detail.plan.id,
                                member.email,
                              ),
                        child: Text(
                          member.isSelf ? '\uB098' : '\uC0AD\uC81C',
                          style: GoogleFonts.notoSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    if (detail.collaborators.any((member) => member.isSelf)) {
      return _buildDetailEmptyState(
        icon: Icons.group_rounded,
        message:
            '\uC774 \uC77C\uC815\uC5D0 \uACF5\uC720 \uCC38\uC5EC \uC911\uC785\uB2C8\uB2E4.',
      );
    }

    return _buildDetailEmptyState(
      icon: Icons.group_outlined,
      message:
          '\uACF5\uB3D9 \uC791\uC5C5\uC790 \uC815\uBCF4\uB97C \uBCFC \uC218 \uC5C6\uC5B4\uC694.',
    );
  }

  Future<void> _refreshPlan() async {
    setState(() {
      _detailFuture = ref
          .read(plansProvider.notifier)
          .getPlanDetail(widget.planId);
    });
  }

  Future<void> _showAddItemDialog(
    String planId, {
    TimeOfDay? initialTime,
  }) async {
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    TimeOfDay? selectedStartTime = initialTime;
    TimeOfDay? selectedEndTime;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  20,
                  24,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '\uD56D\uBAA9 \uCD94\uAC00',
                        style: GoogleFonts.notoSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: '\uC77C\uC815\uBA85',
                          hintText: '\uC77C\uC815 \uC774\uB984\uC744 \uC785\uB825\uD558\uC138\uC694',
                          prefixIcon: Icon(Icons.event_note_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 18, color: Color(0xFF3267A2)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedStartTime == null
                                    ? '\uC2DC\uC791 \uC2DC\uAC04'
                                    : _formatTimeOfDay(selectedStartTime!),
                                style: GoogleFonts.notoSans(
                                  fontSize: 14,
                                  color: selectedStartTime == null
                                      ? Colors.grey
                                      : const Color(0xFF111827),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: sheetContext,
                                  initialTime: selectedStartTime ?? TimeOfDay.now(),
                                );
                                if (picked == null) return;
                                setDialogState(() {
                                  selectedStartTime = picked;
                                });
                              },
                              child: Text(
                                selectedStartTime == null ? '\uC120\uD0DD' : '\uBCC0\uACBD',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_filled, size: 18, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedEndTime == null
                                    ? '\uC885\uB8CC \uC2DC\uAC04'
                                    : _formatTimeOfDay(selectedEndTime!),
                                style: GoogleFonts.notoSans(
                                  fontSize: 14,
                                  color: selectedEndTime == null
                                      ? Colors.grey
                                      : const Color(0xFF111827),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: sheetContext,
                                  initialTime: selectedEndTime ?? selectedStartTime ?? TimeOfDay.now(),
                                );
                                if (picked == null) return;
                                setDialogState(() {
                                  selectedEndTime = picked;
                                });
                              },
                              child: Text(
                                selectedEndTime == null ? '\uC120\uD0DD' : '\uBCC0\uACBD',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(sheetContext).pop(false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                                side: BorderSide(color: Colors.grey.shade300),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('\uCDE8\uC18C'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.of(sheetContext).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3267A2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: const Text('\uCD94\uAC00'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != true || !mounted) {
      titleController.dispose();
      noteController.dispose();
      return;
    }

    final title = titleController.text.trim();
    titleController.dispose();
    noteController.dispose();
    if (title.isEmpty) return;

    try {
      await ref
          .read(plansProvider.notifier)
          .addPlanItem(
            planId: planId,
            draft: PlanDraft(
              title: title,
              note: null,
              startTime: selectedStartTime == null
                  ? null
                  : _formatTimeOfDay(selectedStartTime!),
              endTime: selectedEndTime == null
                  ? null
                  : _formatTimeOfDay(selectedEndTime!),
            ),
          );
      await _refreshPlan();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\uD56D\uBAA9\uC774 \uCD94\uAC00\uB418\uC5C8\uC2B5\uB2C8\uB2E4.',
            style: GoogleFonts.notoSans(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\uD56D\uBAA9 \uCD94\uAC00 \uC2E4\uD328: $e')),
      );
    }
  }



  Future<void> _showJoinByCodeDialog() async {
    final codeController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            '\uCF54\uB4DC\uB85C \uCC38\uAC00',
            style: GoogleFonts.notoSans(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 400,
            child: TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: '\uC77C\uC815 \uCF54\uB4DC',
                hintText: 'PL-260603-ABCD',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('\uCDE8\uC18C'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3267A2),
                foregroundColor: Colors.white,
              ),
              child: const Text('\uCC38\uAC00'),
            ),
          ],
        );
      },
    );

    if (result != true || !mounted) {
      codeController.dispose();
      return;
    }

    final planCode = codeController.text.trim();
    codeController.dispose();
    if (planCode.isEmpty) return;

    try {
      await ref.read(plansProvider.notifier).joinPlanByCode(planCode: planCode);
      await _refreshPlan();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\uC77C\uC815\uC5D0 \uCC38\uAC00\uD588\uC2B5\uB2C8\uB2E4.',
            style: GoogleFonts.notoSans(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('\uCC38\uAC00 \uC2E4\uD328: $e')));
    }
  }

  Future<void> _confirmDeletePlan(PlanSummary plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            '\uC77C\uC815 \uC0AD\uC81C',
            style: GoogleFonts.notoSans(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '\u201C${plan.name}\u201D\uC744 \uC815\uB9D0 \uC0AD\uC81C\uD560\uAE4C\uC694?',
            style: GoogleFonts.notoSans(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('\uCDE8\uC18C'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB45309),
                foregroundColor: Colors.white,
              ),
              child: const Text('\uC0AD\uC81C'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await ref.read(plansProvider.notifier).deletePlan(plan.id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '\uC77C\uC815\uC774 \uC0AD\uC81C\uB418\uC5C8\uC2B5\uB2C8\uB2E4.',
            style: GoogleFonts.notoSans(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('\uC0AD\uC81C \uC2E4\uD328: $e')));
    }
  }

  Future<void> _confirmDeleteItem(String planId, PlanItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            '\uD56D\uBAA9 \uC0AD\uC81C',
            style: GoogleFonts.notoSans(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '\u201C${item.title}\u201D\uC744 \uC9C0\uC6B8\uAE4C\uC694?',
            style: GoogleFonts.notoSans(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('\uCDE8\uC18C'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB45309),
                foregroundColor: Colors.white,
              ),
              child: const Text('\uC0AD\uC81C'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await ref.read(plansProvider.notifier).deletePlanItem(item.id);
      await _refreshPlan();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\uD56D\uBAA9\uC774 \uC0AD\uC81C\uB418\uC5C8\uC2B5\uB2C8\uB2E4.',
            style: GoogleFonts.notoSans(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('\uC0AD\uC81C \uC2E4\uD328: $e')));
    }
  }

  Future<void> _confirmRemoveCollaborator(String planId, String email) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            '\uACF5\uB3D9 \uC791\uC5C5\uC790 \uC0AD\uC81C',
            style: GoogleFonts.notoSans(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '\u201C$email\u201D\uC744 \uBCF8\uB2E4\uACE0 \uC0AD\uC81C\uD560\uAE4C\uC694?',
            style: GoogleFonts.notoSans(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('\uCDE8\uC18C'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB45309),
                foregroundColor: Colors.white,
              ),
              child: const Text('\uC0AD\uC81C'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await ref
          .read(plansProvider.notifier)
          .removeCollaborator(planId: planId, email: email);
      await _refreshPlan();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\uACF5\uB3D9 \uC791\uC5C5\uC790\uAC00 \uC81C\uAC70\uB418\uC5C8\uC2B5\uB2C8\uB2E4.',
            style: GoogleFonts.notoSans(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('\uC0AD\uC81C \uC2E4\uD328: $e')));
    }
  }

  String _formatDate(DateTime date) {
    const weekDays = [
      '\uC77C',
      '\uC6D4',
      '\uD654',
      '\uC218',
      '\uBAA9',
      '\uAE08',
      '\uD1A0',
    ];
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} (${weekDays[date.weekday % 7]})';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatItemTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '\uC2DC\uAC04 \uBBF8\uC815';
    if (raw.length >= 5) return raw.substring(0, 5);
    return raw;
  }
}
