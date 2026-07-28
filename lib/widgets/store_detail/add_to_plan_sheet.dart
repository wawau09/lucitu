import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/plan.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/providers/navigation_provider.dart';
import 'package:placelist/providers/plans_provider.dart';

void showAddToPlanSheet(BuildContext context, WidgetRef ref, Store store) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1C1C1E)
        : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return AddToPlanSheetContent(store: store, parentContext: context);
    },
  );
}

class AddToPlanSheetContent extends ConsumerStatefulWidget {
  final Store store;
  final BuildContext parentContext;

  const AddToPlanSheetContent({
    super.key,
    required this.store,
    required this.parentContext,
  });

  @override
  ConsumerState<AddToPlanSheetContent> createState() => _AddToPlanSheetContentState();
}

class _AddToPlanSheetContentState extends ConsumerState<AddToPlanSheetContent> {
  String selectedTime = '12:00';

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(plansProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.edit_calendar,
                  color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF3267A2),
                ),
                const SizedBox(width: 8),
                Text(
                  '내 일정에 추가',
                  style: GoogleFonts.notoSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '\'${widget.store.name}\' 카페를 방문할 일정을 선택하세요.',
              style: GoogleFonts.notoSans(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            plansAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('일정을 불러오는 중 오류가 발생했습니다: $err'),
              data: (plans) {
                if (plans.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '생성된 일정이 없습니다.',
                          style: GoogleFonts.notoSans(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ref.read(navigationProvider.notifier).setIndex(0);
                            Navigator.pop(widget.parentContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3267A2),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('일정 탭에서 일정 생성하기'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: plans.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                        ),
                        itemBuilder: (ctx, idx) {
                          final plan = plans[idx];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              plan.name,
                              style: GoogleFonts.notoSans(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              '${plan.planDate.year}-${plan.planDate.month.toString().padLeft(2, '0')}-${plan.planDate.day.toString().padLeft(2, '0')}',
                              style: GoogleFonts.notoSans(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.grey[600],
                              ),
                            ),
                            trailing: ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('추가'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3267A2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                try {
                                  await ref.read(plansProvider.notifier).addPlanItem(
                                        planId: plan.id,
                                        draft: PlanDraft(
                                          title: widget.store.name,
                                          startTime: selectedTime,
                                        ),
                                      );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                                      SnackBar(
                                        content: Text('\'${plan.name}\' 일정에 추가되었습니다.'),
                                        action: SnackBarAction(
                                          label: '일정 확인',
                                          onPressed: () {
                                            ref.read(navigationProvider.notifier).setIndex(0);
                                            Navigator.pop(widget.parentContext);
                                          },
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                                      SnackBar(content: Text('일정 추가 실패: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
