import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/plan.dart';
import 'package:placelist/providers/navigation_provider.dart';
import 'package:placelist/providers/plans_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      backgroundColor: const Color(0xFFF6F5F2),
      body: SafeArea(
        bottom: false,
        child: plansAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => _buildErrorState(err.toString()),
          data: (plans) {
            _syncInitialSelection(plans);

            if (user == null) {
              return _buildLoggedOutState();
            }

            final selectedExists =
                _selectedPlanId != null && plans.any((plan) => plan.id == _selectedPlanId);

            if (!selectedExists && _selectedPlanId != null && plans.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _selectedPlanId = plans.first.id;
                  _selectedPlanFuture =
                      ref.read(plansProvider.notifier).getPlanDetail(plans.first.id);
                });
              });
            }

            return RefreshIndicator(
              onRefresh: () => ref.read(plansProvider.notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context, user),
                    const SizedBox(height: 14),
                    _buildSummaryRow(plans),
                    const SizedBox(height: 18),
                    _buildSectionTitle(
                      title: '\uC800\uC7A5\uB41C \uC77C\uC815',
                      subtitle: '\uACC4\uC815\uC5D0 \uC800\uC7A5\uB41C \uAC1C\uBCC4 \uACC4\uD68D\uC744 \uBCFC \uC218 \uC788\uC5B4\uC694',
                    ),
                    const SizedBox(height: 12),
                    if (plans.isEmpty)
                      _buildEmptyPlansCard()
                    else
                      ...plans.map((plan) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildPlanCard(
                              plan: plan,
                              isSelected: plan.id == _selectedPlanId,
                            ),
                          )),
                    const SizedBox(height: 8),
                    if (_selectedPlanId != null) ...[
                      _buildSectionTitle(
                        title: '\uC120\uD0DD\uD55C \uC77C\uC815',
                        subtitle: '\uC77C\uC815, \uC911\uAC04 \uC7A5\uC18C, \uC2DC\uAC04\uC744 \uD558\uB098\uB85C \uAD00\uB9AC\uD569\uB2C8\uB2E4',
                      ),
                      const SizedBox(height: 12),
                      _buildSelectedPlanDetail(),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoggedOutState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE8E1D9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_note_rounded, size: 54, color: Color(0xFF3267A2)),
              const SizedBox(height: 14),
              Text(
                '\uC77C\uC815\uC744 \uBCF4\uB824\uBA74 \uB85C\uADF8\uC778\uC774 \uD544\uC694\uD569\uB2C8\uB2E4',
                style: GoogleFonts.notoSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '\uACC4\uC815\uC5D0 \uC800\uC7A5\uB41C \uACC4\uD68D\uACFC \uACF5\uC720 \uC77C\uC815\uC744 \uC5F4\uB78C\uD560 \uC218 \uC788\uC5B4\uC694.',
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(navigationProvider.notifier).setIndex(2);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3267A2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    '\uACC4\uC815 \uD0ED \uC774\uB3D9',
                    style: GoogleFonts.notoSans(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildHeader(BuildContext context, User user) {
    final metadataName = user.userMetadata?['full_name']?.toString().trim();
    final displayName =
        metadataName != null && metadataName.isNotEmpty ? metadataName : user.email ?? '\uC0AC\uC6A9\uC790';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F5E8F), Color(0xFF86A8C8)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F5E8F).withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\uB0B4 \uC77C\uC815',
                      style: GoogleFonts.notoSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\uACC4\uC815\uC5D0 \uC800\uC7A5\uB41C \uC77C\uC815\uC744 \uD55C \uC7A5\uBA74\uC5D0 \uB9AC\uD2A8\uD569\uB2C8\uB2E4',
                      style: GoogleFonts.notoSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '\uBCC4\uBA85: $displayName',
            style: GoogleFonts.notoSans(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildHeaderChip(
                icon: Icons.add_rounded,
                label: '\uC0C8 \uC77C\uC815',
                onTap: _showCreatePlanDialog,
              ),
              const SizedBox(width: 10),
              _buildHeaderChip(
                icon: Icons.refresh_rounded,
                label: '\uC0C8\uB85C\uACE0\uCE68',
                onTap: () => ref.read(plansProvider.notifier).refresh(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.notoSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(List<PlanSummary> plans) {
    final sharedCount = plans.where((plan) => plan.sharedWithMe).length;
    final totalItems = plans.fold<int>(0, (sum, plan) => sum + plan.itemCount);

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            label: '\uC800\uC7A5\uB41C \uC77C\uC815',
            value: '${plans.length}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            label: '\uACF5\uC720 \uC77C\uC815',
            value: '$sharedCount',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            label: '\uD56D\uBAA9 \uC218',
            value: '$totalItems',
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9E2D9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.notoSans(
              fontSize: 11,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.notoSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.notoSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.notoSans(
            fontSize: 13,
            color: const Color(0xFF6B7280),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPlansCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8E1D9)),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_busy_rounded, size: 42, color: Color(0xFFB3B9C4)),
          const SizedBox(height: 12),
          Text(
            '\uC544\uC9C1 \uC800\uC7A5\uB41C \uC77C\uC815\uC774 \uC5C6\uC5B4\uC694',
            style: GoogleFonts.notoSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '\uC0C8 \uC77C\uC815\uC744 \uB9CC\uB4E4\uACE0 \uC77C\uC815\uACFC \uC7A5\uC18C, \uC2DC\uAC04\uC744 \uB123\uC5B4\uBCF4\uC138\uC694.',
            style: GoogleFonts.notoSans(
              fontSize: 13,
              color: const Color(0xFF6B7280),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _showCreatePlanDialog,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              '\uC77C\uC815 \uB9CC\uB4E4\uAE30',
              style: GoogleFonts.notoSans(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3267A2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required PlanSummary plan,
    required bool isSelected,
  }) {
    final borderColor = isSelected ? const Color(0xFF3267A2) : const Color(0xFFE8E1D9);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPlanId = plan.id;
          _selectedPlanFuture = ref.read(plansProvider.notifier).getPlanDetail(plan.id);
        });
      },
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.08 : 0.04),
              blurRadius: isSelected ? 18 : 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3267A2).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.event_note_rounded, color: Color(0xFF3267A2)),
                ),
                const SizedBox(width: 12),
                Expanded(
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
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF111827),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (plan.sharedWithMe)
                            _buildPill(
                              label: '\uACF5\uC720\uC911',
                              background: const Color(0xFFF0F6FF),
                              foreground: const Color(0xFF2F5E8F),
                            )
                          else
                            _buildPill(
                              label: '\uB0B4 \uC77C\uC815',
                              background: const Color(0xFFF5F7FB),
                              foreground: const Color(0xFF374151),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDate(plan.planDate),
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E1D9)),
              ),
              child: Text(
                plan.planCode,
                style: GoogleFonts.notoSans(
                  fontSize: 12,
                  letterSpacing: 1.1,
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMiniStat(icon: Icons.list_alt_rounded, label: '\uD56D\uBAA9', value: '${plan.itemCount}'),
                const SizedBox(width: 10),
                _buildMiniStat(
                  icon: plan.sharedWithMe ? Icons.group_rounded : Icons.person_rounded,
                  label: plan.sharedWithMe ? '\uACF5\uC720' : '\uC18C\uC720',
                  value: plan.sharedWithMe ? '\uACF5\uC720' : '\uB0B4',
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedPlanId = plan.id;
                      _selectedPlanFuture = ref.read(plansProvider.notifier).getPlanDetail(plan.id);
                    });
                  },
                  child: Text(
                    '\uC5F4\uAE30',
                    style: GoogleFonts.notoSans(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3267A2),
                    ),
                  ),
                ),
                if (plan.isOwner) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _confirmDeletePlan(plan),
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: const Color(0xFFB45309),
                    tooltip: '\uC0AD\uC81C',
                  ),
                ],
              ],
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
        final itemPlaces = detail.items
            .map((item) => item.placeName?.trim())
            .whereType<String>()
            .where((place) => place.isNotEmpty)
            .toSet()
            .toList();

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
                      await Clipboard.setData(ClipboardData(text: detail.plan.planCode));
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
                    label: detail.plan.isOwner ? '\uC18C\uC720\uC790' : '\uACF5\uC720 \uCC38\uC5EC\uC790',
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
                        style: GoogleFonts.notoSans(fontWeight: FontWeight.w700),
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
                      onPressed: detail.plan.isOwner
                          ? () => _showAddCollaboratorDialog(detail.plan.id)
                          : null,
                      icon: const Icon(Icons.group_add_rounded, size: 18),
                      label: Text(
                        '\uACF5\uC720',
                        style: GoogleFonts.notoSans(fontWeight: FontWeight.w700),
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
                        message: '\uC544\uC9C1 \uC77C\uC815 \uD56D\uBAA9\uC774 \uC5C6\uC5B4\uC694.',
                      )
                    : Column(
                        children: detail.items
                            .map(
                              (item) => _buildScheduleRow(
                                item,
                                onDelete: () => _confirmDeleteItem(detail.plan.id, item),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 14),
              _buildDetailSection(
                title: '\uC911\uAC04\uC5D0 \uB4E4\uB9B4 \uC7A5\uC18C',
                child: itemPlaces.isEmpty
                    ? _buildDetailEmptyState(
                        icon: Icons.place_outlined,
                        message: '\uC911\uAC04\uC7A5\uC18C\uAC00 \uC544\uC9C1 \uC5C6\uC5B4\uC694.',
                      )
                    : Column(
                        children: itemPlaces
                            .map(
                              (place) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildPlaceChip(place),
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
                        message: '\uC2DC\uAC04 \uAE30\uBC18 \uC77C\uC815\uC774 \uC544\uC9C1 \uC5C6\uC5B4\uC694.',
                      )
                    : Column(
                        children: detail.items
                            .map((item) => _buildTimelineRow(item))
                            .toList(),
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

  Widget _buildDetailSection({
    required String title,
    required Widget child,
  }) {
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if ((item.placeName ?? '').isNotEmpty)
                    Text(
                      item.placeName!,
                      style: GoogleFonts.notoSans(
                        fontSize: 13,
                        color: const Color(0xFF6B7280),
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
          const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF3267A2)),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.placeName != null && item.placeName!.isNotEmpty
                        ? item.placeName!
                        : '\uC7A5\uC18C \uC5C6\uC74C',
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
          message: '\uC544\uC9C1 \uB4F1\uB85D\uB41C \uACF5\uB3D9 \uC791\uC5C5\uC790\uAC00 \uC5C6\uC5B4\uC694.',
        );
      }

      return Column(
        children: detail.collaborators
            .map(
              (member) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE8E1D9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_rounded, color: Color(0xFF3267A2), size: 18),
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
                            : () => _confirmRemoveCollaborator(detail.plan.id, member.email),
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
        message: '\uC774 \uC77C\uC815\uC5D0 \uACF5\uC720 \uCC38\uC5EC \uC911\uC785\uB2C8\uB2E4.',
      );
    }

    return _buildDetailEmptyState(
      icon: Icons.group_outlined,
      message: '\uACF5\uB3D9 \uC791\uC5C5\uC790 \uC815\uBCF4\uB97C \uBCFC \uC218 \uC5C6\uC5B4\uC694.',
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
          _selectedPlanFuture =
              ref.read(plansProvider.notifier).getPlanDetail(plans.first.id);
        });
      }
      _queuedInitialSelection = false;
    });
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                            style: GoogleFonts.notoSans(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
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
        _selectedPlanFuture = ref.read(plansProvider.notifier).getPlanDetail(created.id);
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

  Future<void> _showAddItemDialog(String planId) async {
    final titleController = TextEditingController();
    final placeController = TextEditingController();
    final noteController = TextEditingController();
    TimeOfDay? selectedTime;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                '\uD56D\uBAA9 \uCD94\uAC00',
                style: GoogleFonts.notoSans(fontWeight: FontWeight.w800),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: '\uC81C\uBAA9'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: placeController,
                        decoration: const InputDecoration(labelText: '\uC7A5\uC18C'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(labelText: '\uBA54\uBAA8'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedTime == null
                                  ? '\uC2DC\uAC04 \uC5C6\uC74C'
                                  : _formatTimeOfDay(selectedTime!),
                              style: GoogleFonts.notoSans(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedTime ?? TimeOfDay.now(),
                              );
                              if (picked == null) return;
                              setDialogState(() {
                                selectedTime = picked;
                              });
                            },
                            child: const Text('\uC2DC\uAC04 \uC120\uD0DD'),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                  child: const Text('\uC800\uC7A5'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) {
      titleController.dispose();
      placeController.dispose();
      noteController.dispose();
      return;
    }

    final title = titleController.text.trim();
    if (title.isEmpty) {
      titleController.dispose();
      placeController.dispose();
      noteController.dispose();
      return;
    }

    try {
      await ref.read(plansProvider.notifier).addPlanItem(
            planId: planId,
            draft: PlanDraft(
              title: title,
              placeName: placeController.text.trim(),
              note: noteController.text.trim(),
              startTime: selectedTime == null ? null : _formatTimeOfDay(selectedTime!),
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
      placeController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _showAddCollaboratorDialog(String planId) async {
    final emailController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            '\uACF5\uB3D9 \uC791\uC5C5\uC790 \uCD94\uAC00',
            style: GoogleFonts.notoSans(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: '\uC774\uBA54\uC77C',
                    hintText: 'friend@example.com',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '\uC774\uBA54\uC77C\uB85C \uACF5\uC720\uD558\uBA74 \uB2E4\uB978 \uACC4\uC815\uC5D0\uC11C\uB3C4 \uC774 \uC77C\uC815\uC744 \uBCFC \uC218 \uC788\uC5B4\uC694.',
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
              child: const Text('\uCD08\uB300'),
            ),
          ],
        );
      },
    );

    if (result != true || !mounted) {
      emailController.dispose();
      return;
    }

    final email = emailController.text.trim();
    emailController.dispose();
    if (email.isEmpty) return;

    try {
      await ref.read(plansProvider.notifier).addCollaborator(planId: planId, email: email);
      _reloadSelectedPlan(planId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\uACF5\uB3D9 \uC791\uC5C5\uC790\uAC00 \uCD94\uAC00\uB418\uC5C8\uC2B5\uB2C8\uB2E4.',
            style: GoogleFonts.notoSans(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\uACF5\uC720 \uCD94\uAC00 \uC2E4\uD328: $e')),
      );
    }
  }

  Future<void> _confirmDeletePlan(PlanSummary plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
      await ref.read(plansProvider.notifier).removeCollaborator(planId: planId, email: email);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\uC0AD\uC81C \uC2E4\uD328: $e')),
      );
    }
  }

  void _reloadSelectedPlan(String planId) {
    setState(() {
      _selectedPlanFuture = ref.read(plansProvider.notifier).getPlanDetail(planId);
    });
  }

  String _formatDate(DateTime date) {
    const weekDays = ['\uC77C', '\uC6D4', '\uD654', '\uC218', '\uBAA9', '\uAE08', '\uD1A0'];
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
