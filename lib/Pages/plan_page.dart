import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/plan.dart';
import 'package:placelist/providers/navigation_provider.dart';
import 'package:placelist/providers/plans_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:placelist/widgets/clock_schedule.dart';
import 'package:placelist/widgets/plan_share_card.dart';
import 'package:placelist/widgets/plan_item_form_sheet.dart';
import 'package:placelist/widgets/plan/plan_collaborator_section.dart';
import 'package:placelist/widgets/plan/plan_card_item.dart';
import 'package:placelist/utils/share_helper.dart';
import 'package:placelist/widgets/plan/plan_header_widget.dart';
import 'package:placelist/widgets/shimmer_loading.dart';
import 'package:placelist/widgets/error_retry_widget.dart';
import 'package:placelist/Pages/cupertino_planner_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:placelist/utils/app_colors.dart';
import 'package:placelist/providers/stores_provider.dart';
import 'package:placelist/DB/store.dart';

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
  final GlobalKey _shareCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboardForPlanCode();
    });
  }

  Future<void> _checkClipboardForPlanCode() async {
    if (kIsWeb) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null &&
          ((text.length >= 4 && text.length <= 8 && RegExp(r'^[A-Za-z0-9]+$').hasMatch(text)) ||
              (text.toUpperCase().startsWith('PL-') && text.length >= 8))) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('복사된 일정 코드($text)를 발견했습니다!'),
            action: SnackBarAction(
              label: '참가하기',
              onPressed: () => _joinByCode(text),
            ),
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _joinByCode(String code) async {
    try {
      final joined = await ref.read(plansProvider.notifier).joinPlanByCode(planCode: code);
      _reloadSelectedPlan(joined.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('일정에 성공적으로 참가했습니다!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('일정 참가 실패: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _client.auth.currentUser;
    final plansAsync = ref.watch(plansProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlanHeaderWidget(
              isDark: isDark,
              onRefresh: () => ref.read(plansProvider.notifier).refresh(),
              onAddPlan: _showPlanActionChooser,
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEEEEEE)),
            Expanded(
              child: plansAsync.when(
                loading: () => ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: 4,
                  itemBuilder: (context, index) => const PlanSkeletonCard(),
                ),
                error: (err, stack) => ErrorRetryWidget(
                  message: err.toString(),
                  onRetry: () => ref.read(plansProvider.notifier).refresh(),
                ),
                data: (plans) {
                  if (user == null) {
                    return _buildLoggedOutState(isDark);
                  }

                  if (plans.isEmpty) {
                    return _buildEmptyPlansCard(isDark);
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref.read(plansProvider.notifier).refresh(),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: plans.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEEEEEE),
                      ),
                      itemBuilder: (context, index) {
                        final plan = plans[index];
                        return PlanCardItem(
                          plan: plan,
                          isDark: isDark,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlanDetailPage(planId: plan.id),
                              ),
                            );
                          },
                          onDelete: () => _confirmDeletePlan(plan),
                        );
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

  Widget _buildLoggedOutState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note_outlined, size: 80, color: isDark ? Colors.white10 : Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            "일정을 보려면 로그인이 필요합니다.",
            style: GoogleFonts.notoSans(color: isDark ? Colors.white38 : Colors.grey, fontSize: 15),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(navigationProvider.notifier).setIndex(2),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black87,
              foregroundColor: isDark ? Colors.black87 : Colors.white,
            ),
            child: const Text('로그인 하러 가기'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '일정을 불러오는 중 오류가 발생했습니다.\n$message',
          style: GoogleFonts.notoSans(color: isDark ? Colors.white70 : Colors.black87, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildEmptyPlansCard(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_outlined, size: 80, color: isDark ? Colors.white10 : Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            "아직 등록된 일정이 없네요!",
            style: GoogleFonts.notoSans(color: isDark ? Colors.white38 : Colors.grey, fontSize: 15),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _showCreatePlanDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black87,
              foregroundColor: isDark ? Colors.black87 : Colors.white,
            ),
            child: const Text('새 일정 만들기'),
          ),
        ],
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
                title: '일정 타임라인',
                child: detail.items.isEmpty
                    ? _buildDetailEmptyState(
                        icon: Icons.calendar_today_outlined,
                        message: '아직 일정 항목이 없어요.',
                      )
                    : Column(
                        children: detail.items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return _buildScheduleRow(
                            item,
                            index: index + 1,
                            isFirst: index == 0,
                            isLast: index == detail.items.length - 1,
                            onDelete: () =>
                                _confirmDeleteItem(detail.plan.id, item),
                            planId: detail.plan.id,
                          );
                        }).toList(),
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
                          _showEditItemDialog(item, detail.plan.id);
                        },
                      ),
              ),
              if (detail.items.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildShareButton(detail),
              ],
              const SizedBox(height: 14),
              _buildDetailSection(
                title: '공동 작업자',
                child: PlanCollaboratorSection(
                  detail: detail,
                  onRemoveCollaborator: (member) =>
                      _confirmRemoveCollaborator(detail.plan.id, member),
                ),
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

  Future<void> _confirmRemoveCollaborator(
    String planId,
    PlanCollaborator member,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('공동 작업자 내보내기'),
        content: Text('${member.name} 님을 이 일정에서 내보내시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('내보내기'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await ref.read(plansProvider.notifier).removeCollaborator(
              planId: planId,
              email: member.email,
            );
        _reloadSelectedPlan(planId);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내보내기 실패: $e')),
        );
      }
    }
  }

  // ── 공유 버튼 ──
  Widget _buildShareButton(PlanDetail detail) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showShareDialog(detail),
        icon: const Icon(Icons.ios_share_rounded, size: 17),
        label: Text(
          '일정 카드로 공유하기',
          style: GoogleFonts.notoSans(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF6C63FF),
          side: BorderSide(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
          ),
          backgroundColor: isDark
              ? const Color(0xFF6C63FF).withValues(alpha: 0.08)
              : const Color(0xFF6C63FF).withValues(alpha: 0.04),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ── 공유 미리보기 다이얼로그 ──
  Future<void> _showShareDialog(PlanDetail detail) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _SharePreviewSheet(
          shareCardKey: _shareCardKey,
          plan: detail.plan,
          items: detail.items,
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

  String _getFormattedTimeRange(PlanItem item) {
    final start = _formatItemTime(item.startTime);
    if (start == '시간 미정') return start;
    if (item.endTime != null && item.endTime!.isNotEmpty) {
      final end = _formatItemTime(item.endTime);
      return '$start ~ $end';
    }
    return start;
  }

  Widget _buildScheduleRow(
    PlanItem item, {
    required VoidCallback onDelete,
    required String planId,
    int index = 1,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stores = ref.watch(storesProvider).valueOrNull ?? [];
    Store? matchingStore;
    for (final s in stores) {
      if (s.name.trim().toLowerCase() == item.title.trim().toLowerCase()) {
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

    final timeStr = _getFormattedTimeRange(item);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 왼쪽 세로 라인 + 번호/시간 마커
          SizedBox(
            width: 44,
            child: Column(
              children: [
                // 상단 세로 라인
                Container(
                  width: 2,
                  height: 12,
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
                        color: (isDark ? Colors.black : AppColors.primary).withValues(alpha: 0.2),
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
          const SizedBox(width: 8),

          // 2. 오른쪽 타임라인 카드 (정사각형 1:1 썸네일 Radius 12 + 카페명 Bold 16px + 태그)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _showEditItemDialog(item, planId),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // 카페 썸네일 (정사각형 1:1, Radius 12)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 68,
                          height: 68,
                          child: imageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF4EDE6),
                                    child: Icon(
                                      Icons.coffee_rounded,
                                      color: isDark ? Colors.white38 : AppColors.accent,
                                      size: 26,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF4EDE6),
                                  child: Icon(
                                    Icons.coffee_rounded,
                                    color: isDark ? Colors.white38 : AppColors.accent,
                                    size: 26,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 카페명 & 시간 & 태그
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 시간 뱃지
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_filled_rounded,
                                  size: 12,
                                  color: isDark ? AppColors.accentLight : AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  timeStr,
                                  style: GoogleFonts.notoSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.accentLight : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // 카페명 (Bold 16px)
                            Text(
                              item.title,
                              style: GoogleFonts.notoSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // 태그 (#전포 #오션뷰)
                            if (tags.isNotEmpty)
                              Wrap(
                                spacing: 4,
                                children: tags.map((t) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF4F5F6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      t,
                                      style: GoogleFonts.notoSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white60 : Colors.grey[700],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),

                      // 삭제 버튼
                      IconButton(
                        onPressed: onDelete,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: isDark ? Colors.white38 : Colors.grey[400],
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: '삭제',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(PlanItem item) {
    final timeStr = _getFormattedTimeRange(item);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 계획명
                Text(
                  item.title,
                  style: GoogleFonts.notoSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                // 계획명 밑에 표시되는 시간
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: Color(0xFF6C63FF),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6C63FF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaboratorSection(PlanDetail detail) {
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
                        member.name,
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (detail.plan.isOwner)
                      TextButton(
                        onPressed: member.isSelf
                            ? null
                            : () => _confirmRemoveCollaborator(
                                detail.plan.id,
                                member,
                              ),
                        child: Text(
                          member.isSelf ? '\uB098' : '\uC0AD\uC81C',
                          style: GoogleFonts.notoSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else if (member.isSelf)
                      Text(
                        '\uB098',
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3267A2),
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title row
                  Row(
                    children: [
                      Text(
                        '일정 추가',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ── 새 일정 만들기 card ──
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showCreatePlanDialog();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A90E2), Color(0xFF6C63FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A90E2).withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text('✈️', style: TextStyle(fontSize: 26)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '새 일정 만들기',
                                  style: GoogleFonts.notoSansKr(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '나만의 여행 일정을 처음부터 계획해요',
                                  style: GoogleFonts.notoSansKr(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── 코드로 참가 card ──
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showJoinByCodeDialog();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF8C42), Color(0xFFFF6B6B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF8C42).withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text('🎟️', style: TextStyle(fontSize: 26)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '코드로 참가하기',
                                  style: GoogleFonts.notoSansKr(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '초대 코드로 친구의 일정에 합류해요',
                                  style: GoogleFonts.notoSansKr(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
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
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Header gradient banner ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF4A90E2), Color(0xFF6C63FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Text('✈️', style: TextStyle(fontSize: 26)),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '새 일정 만들기',
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '특별한 하루를 계획해 보세요',
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ── Form body ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '일정 이름',
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6B7280),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: TextField(
                                  controller: nameController,
                                  style: GoogleFonts.notoSansKr(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF111827),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '예) 제주도 당일치기 🌊',
                                    hintStyle: GoogleFonts.notoSansKr(
                                      color: const Color(0xFF9CA3AF),
                                      fontSize: 14,
                                    ),
                                    prefixIcon: const Icon(Icons.edit_outlined, color: Color(0xFF9CA3AF), size: 20),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                '여행 날짜',
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6B7280),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
                                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                                    builder: (context, child) => Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xFF4A90E2),
                                          onPrimary: Colors.white,
                                        ),
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (picked == null) return;
                                  setDialogState(() => selectedDate = picked);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F6FF),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF4A90E2).withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, color: Color(0xFF4A90E2), size: 18),
                                      const SizedBox(width: 12),
                                      Text(
                                        _formatDate(selectedDate),
                                        style: GoogleFonts.notoSansKr(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF4A90E2),
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF4A90E2), size: 18),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],
                          ),
                        ),
                        // ── Action buttons ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.of(dialogContext).pop(false),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                                    ),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '취소',
                                      style: GoogleFonts.notoSansKr(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4A90E2), Color(0xFF6C63FF)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4A90E2).withOpacity(0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '일정 생성하기 ✨',
                                        style: GoogleFonts.notoSansKr(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlanDetailPage(planId: created.id)),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '일정이 생성되었습니다.',
            style: GoogleFonts.notoSans(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정 생성 실패: $e')),
      );
    }
  }

  Future<void> _showJoinByCodeDialog() async {
    final codeController = TextEditingController();
    bool isLoading = false;
    String? errorMsg;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Header gradient banner ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFF8C42), Color(0xFFFF6B6B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Text('🎟️', style: TextStyle(fontSize: 26)),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '코드로 참가하기',
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '초대 코드를 입력해 일정에 합류하세요',
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ── Code input body ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '초대 코드',
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6B7280),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7F0),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: errorMsg != null
                                        ? Colors.redAccent
                                        : const Color(0xFFFF8C42).withOpacity(0.4),
                                  ),
                                ),
                                child: TextField(
                                  controller: codeController,
                                  enabled: !isLoading,
                                  textCapitalization: TextCapitalization.characters,
                                  onChanged: (_) {
                                    if (errorMsg != null) {
                                      setDialogState(() => errorMsg = null);
                                    }
                                  },
                                  style: GoogleFonts.notoSansKr(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    color: const Color(0xFF111827),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '1ADB',
                                    hintStyle: GoogleFonts.notoSansKr(
                                      color: const Color(0xFFD1D5DB),
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.normal,
                                    ),
                                    prefixIcon: const Icon(Icons.confirmation_num_outlined, color: Color(0xFFFF8C42), size: 20),
                                    border: InputBorder.none,
                                    counterText: '',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  ),
                                ),
                              ),
                              if (errorMsg != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        errorMsg!,
                                        style: GoogleFonts.notoSansKr(
                                          fontSize: 12,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFF8C42).withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Text('💡', style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '초대 코드는 일정 상세 화면에서 확인할 수 있어요',
                                        style: GoogleFonts.notoSansKr(
                                          fontSize: 12,
                                          color: const Color(0xFFB45309),
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],
                          ),
                        ),
                        // ── Action buttons ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: isLoading ? null : () => Navigator.of(dialogContext).pop(),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                                    ),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '취소',
                                      style: GoogleFonts.notoSansKr(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: isLoading
                                        ? const LinearGradient(colors: [Color(0xFFD1D5DB), Color(0xFF9CA3AF)])
                                        : const LinearGradient(
                                            colors: [Color(0xFFFF8C42), Color(0xFFFF6B6B)],
                                          ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: isLoading
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: const Color(0xFFFF8C42).withOpacity(0.4),
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: isLoading
                                        ? null
                                        : () async {
                                            final code = codeController.text.trim();
                                            if (code.isEmpty) {
                                              setDialogState(() => errorMsg = '초대 코드를 입력해 주세요.');
                                              return;
                                            }
                                            setDialogState(() {
                                              isLoading = true;
                                              errorMsg = null;
                                            });
                                            try {
                                              final joined = await ref
                                                  .read(plansProvider.notifier)
                                                  .joinPlanByCode(planCode: code);
                                              if (!mounted) return;
                                              Navigator.of(dialogContext).pop();
                                              _reloadSelectedPlan(joined.id);
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => PlanDetailPage(planId: joined.id),
                                                ),
                                              );
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '🎉 "${joined.name}" 일정에 참가했습니다!',
                                                    style: GoogleFonts.notoSans(),
                                                  ),
                                                  behavior: SnackBarBehavior.floating,
                                                  backgroundColor: const Color(0xFFFF8C42),
                                                ),
                                              );
                                            } catch (e) {
                                              setDialogState(() {
                                                isLoading = false;
                                                errorMsg = '코드를 찾을 수 없습니다. 다시 확인해주세요.';
                                              });
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '참가하기 🎟️',
                                              style: GoogleFonts.notoSansKr(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    codeController.dispose();
  }

  Future<void> _showAddItemDialog(String planId, {TimeOfDay? initialTime}) async {
    final draft = await showPlanItemFormSheet(
      context,
      isEdit: false,
      initialTime: initialTime,
    );
    if (draft == null || !mounted) return;

    try {
      await ref.read(plansProvider.notifier).addPlanItem(
            planId: planId,
            draft: draft,
          );
      _reloadSelectedPlan(planId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('항목 추가 실패: $e')),
      );
    }
  }



  Future<void> _showEditItemDialog(PlanItem item, String planId) async {
    final draft = await showPlanItemFormSheet(
      context,
      isEdit: true,
      initial: item,
    );
    if (draft == null || !mounted) return;

    try {
      await ref.read(plansProvider.notifier).updatePlanItem(
            itemId: item.id,
            draft: draft,
          );
      _reloadSelectedPlan(planId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('항목 수정 실패: $e')),
      );
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

class OldPlanDetailPage extends ConsumerStatefulWidget {
  const OldPlanDetailPage({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<OldPlanDetailPage> createState() => _OldPlanDetailPageState();
}

class _OldPlanDetailPageState extends ConsumerState<OldPlanDetailPage> {
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
                  _buildDetailSection(
                    title: '시간별',
                    child: detail.items.isEmpty
                        ? _buildDetailEmptyState(
                            icon: Icons.schedule_outlined,
                            message: '시간 기반 일정이 아직 없어요.',
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
                    width: 44,
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
                  const SizedBox(width: 6),
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
                  const SizedBox(width: 6),
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
                              Color? bgColor;
                              Color? borderColor;
                              if (item.color != null) {
                                final baseColor = Color(int.parse(item.color!.substring(1, 7), radix: 16) + 0xFF000000);
                                bgColor = baseColor.withOpacity(0.1);
                                borderColor = baseColor.withOpacity(0.3);
                              }
                              
                              return GestureDetector(
                                onTap: () => _showEditItemDialog(item, detail.plan.id),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: bgColor ?? const Color(0xFFF0F6FF),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: borderColor ?? const Color(0xFFBFDBFE),
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
                                ),
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
              width: 48,
              child: Text(
                _formatItemTime(item.startTime),
                style: GoogleFonts.notoSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF3267A2),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF3267A2),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              _formatItemTime(item.startTime),
              style: GoogleFonts.notoSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF3267A2),
              ),
            ),
          ),
          const SizedBox(width: 6),
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
            child: Text(
              item.title,
              style: GoogleFonts.notoSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaboratorSection(PlanDetail detail) {
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
                        member.name,
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (detail.plan.isOwner)
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
                      )
                    else if (member.isSelf)
                      Text(
                        '\uB098',
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3267A2),
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
    final draft = await showPlanItemFormSheet(
      context,
      isEdit: false,
      initialTime: initialTime,
    );
    if (draft == null || !mounted) return;

    try {
      await ref.read(plansProvider.notifier).addPlanItem(
            planId: planId,
            draft: draft,
          );
      await _refreshPlan();
    } catch (e) {
      if (!mounted) return;
    }
  }

  Future<void> _showEditItemDialog(PlanItem item, String planId) async {
    final draft = await showPlanItemFormSheet(
      context,
      isEdit: true,
      initial: item,
    );
    if (draft == null || !mounted) return;

    try {
      await ref.read(plansProvider.notifier).updatePlanItem(
            itemId: item.id,
            draft: draft,
          );
      await _refreshPlan();
    } catch (e) {
      if (!mounted) return;
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
                hintText: '1ADB',
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
                  "시간: ${_formatItemTime(item.startTime)}${item.endTime != null ? ' ~ ${_formatItemTime(item.endTime)}' : ''}",
                  style: const TextStyle(fontSize: 14),
                ),
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

const List<String?> _planColors = [
  null,
  '#EF4444', // Red
  '#F59E0B', // Amber
  '#10B981', // Emerald
  '#3B82F6', // Blue
  '#8B5CF6', // Purple
  '#EC4899', // Pink
];

class _TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    if (!RegExp(r'^[0-9:]*$').hasMatch(text)) return oldValue;

    final digits = text.replaceAll(':', '');
    if (digits.length > 4) return oldValue;

    if (digits.length >= 2) {
      final h = int.tryParse(digits.substring(0, 2));
      if (h != null && h >= 24) return oldValue;
    }
    if (digits.length == 4) {
      final m = int.tryParse(digits.substring(2, 4));
      if (m != null && m >= 60) return oldValue;
    }

    return newValue;
  }
}

// ─────────────────────────────────────────────
// 공유 카드 미리보기 바텀시트
// ─────────────────────────────────────────────
class _SharePreviewSheet extends StatefulWidget {
  final GlobalKey shareCardKey;
  final PlanSummary plan;
  final List<PlanItem> items;

  const _SharePreviewSheet({
    required this.shareCardKey,
    required this.plan,
    required this.items,
  });

  @override
  State<_SharePreviewSheet> createState() => _SharePreviewSheetState();
}

class _SharePreviewSheetState extends State<_SharePreviewSheet> {
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0A1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // 제목
              Row(
                children: [
                  const Text('📤', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Text(
                    '일정 카드 공유',
                    style: GoogleFonts.notoSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '아래 카드를 이미지로 저장하거나\n인스타, 카카오톡 등에 공유할 수 있어요.',
                  style: GoogleFonts.notoSans(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.55),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 카드 미리보기 (캡처 대상)
              Center(
                child: PlanShareCard(
                  repaintKey: widget.shareCardKey,
                  plan: widget.plan,
                  items: widget.items,
                ),
              ),
              const SizedBox(height: 24),

              // 공유 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSharing ? null : _onShare,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.ios_share_rounded, size: 20),
                  label: Text(
                    _isSharing ? '이미지 준비 중...' : '공유하기',
                    style: GoogleFonts.notoSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onShare() async {
    setState(() => _isSharing = true);
    try {
      // 렌더 완료 대기
      await Future.delayed(const Duration(milliseconds: 200));

      // RenderBox 위치 획득 (iPad 팝오버 대응)
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      await captureAndShare(
        repaintKey: widget.shareCardKey,
        shareText: '${widget.plan.name} — Loci로 만든 나의 하루 일정 🌸',
        pixelRatio: 3.0,
        sharePositionOrigin: origin,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }
}
