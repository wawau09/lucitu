import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/plan.dart';

// 앱 전체에서 사용하는 일정 색상 팔레트
const List<String?> kPlanColors = [
  null,
  '#EF4444',
  '#F59E0B',
  '#10B981',
  '#3B82F6',
  '#8B5CF6',
  '#EC4899',
];

/// 일정 항목 추가/수정 시 뜨는 감성 바텀시트.
///
/// [isEdit]  - true면 수정 모드, false면 추가 모드
/// [initial] - 수정 모드 시 기존 [PlanItem] 전달
/// [initialTime] - 추가 모드 시 타임라인 탭으로 설정된 초기 시각
///
/// 반환값: 저장 시 [PlanDraft], 취소/닫기 시 null
Future<PlanDraft?> showPlanItemFormSheet(
  BuildContext context, {
  bool isEdit = false,
  PlanItem? initial,
  TimeOfDay? initialTime,
}) {
  return showModalBottomSheet<PlanDraft?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PlanItemFormSheet(
      isEdit: isEdit,
      initial: initial,
      initialTime: initialTime,
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// 바텀시트 본체
// ─────────────────────────────────────────────────────────────
class _PlanItemFormSheet extends StatefulWidget {
  final bool isEdit;
  final PlanItem? initial;
  final TimeOfDay? initialTime;

  const _PlanItemFormSheet({
    required this.isEdit,
    this.initial,
    this.initialTime,
  });

  @override
  State<_PlanItemFormSheet> createState() => _PlanItemFormSheetState();
}

class _PlanItemFormSheetState extends State<_PlanItemFormSheet> {
  late final TextEditingController _titleCtrl;

  // 시작 시간
  late int _startH;
  late int _startM;
  late final FixedExtentScrollController _startHCtrl;
  late final FixedExtentScrollController _startMCtrl;

  // 종료 시간
  late int _endH;
  late int _endM;
  late final FixedExtentScrollController _endHCtrl;
  late final FixedExtentScrollController _endMCtrl;

  bool _hasEndTime = false;
  String? _selectedColor;

  static const _accent = Color(0xFF6C63FF);
  static const _bg = Color(0xFF0F0A1E);

  @override
  void initState() {
    super.initState();

    final item = widget.initial;
    _titleCtrl = TextEditingController(text: item?.title ?? '');
    _selectedColor = item?.color;

    // 시작 시간 초기값
    final sh = _parseHour(item?.startTime) ?? widget.initialTime?.hour ?? 9;
    final sm = _parseMin(item?.startTime) ?? widget.initialTime?.minute ?? 0;
    _startH = sh;
    _startM = sm;
    _startHCtrl = FixedExtentScrollController(initialItem: sh);
    _startMCtrl = FixedExtentScrollController(initialItem: sm ~/ 5);

    // 종료 시간 초기값
    final eh = _parseHour(item?.endTime) ?? (sh + 1).clamp(0, 23);
    final em = _parseMin(item?.endTime) ?? sm;
    _endH = eh;
    _endM = em;
    _endHCtrl = FixedExtentScrollController(initialItem: eh);
    _endMCtrl = FixedExtentScrollController(initialItem: em ~/ 5);
    _hasEndTime = item?.endTime != null;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _startHCtrl.dispose();
    _startMCtrl.dispose();
    _endHCtrl.dispose();
    _endMCtrl.dispose();
    super.dispose();
  }

  int? _parseHour(String? t) {
    if (t == null || t.isEmpty) return null;
    final p = t.split(':');
    return p.isNotEmpty ? int.tryParse(p[0]) : null;
  }

  int? _parseMin(String? t) {
    if (t == null || t.isEmpty) return null;
    final p = t.split(':');
    return p.length >= 2 ? int.tryParse(p[1]) : null;
  }

  String _fmt(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final draft = PlanDraft(
      title: title,
      startTime: _fmt(_startH, _startM),
      endTime: _hasEndTime ? _fmt(_endH, _endM) : null,
      color: _selectedColor,
    );
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 40,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, keyboardH + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 핸들 ──
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // ── 헤더 ──
            _buildHeader(),
            const SizedBox(height: 24),

            // ── 제목 입력 ──
            _buildTitleField(),
            const SizedBox(height: 24),

            // ── 시작 시간 ──
            _buildTimeSectionLabel('시작 시간', Icons.play_circle_outline_rounded),
            const SizedBox(height: 10),
            _buildTimePicker(
              hCtrl: _startHCtrl,
              mCtrl: _startMCtrl,
              onHourChanged: (v) => _startH = v,
              onMinChanged: (v) => _startM = v * 5,
            ),
            const SizedBox(height: 20),

            // ── 종료 시간 토글 ──
            _buildEndTimeToggle(),
            if (_hasEndTime) ...[
              const SizedBox(height: 12),
              _buildTimePicker(
                hCtrl: _endHCtrl,
                mCtrl: _endMCtrl,
                onHourChanged: (v) => _endH = v,
                onMinChanged: (v) => _endM = v * 5,
              ),
            ],
            const SizedBox(height: 24),

            // ── 색상 팔레트 ──
            _buildTimeSectionLabel('색상', Icons.palette_outlined),
            const SizedBox(height: 12),
            _buildColorPicker(),
            const SizedBox(height: 28),

            // ── 액션 버튼 ──
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // ── 헤더 ──
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.schedule_rounded, color: _accent, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          widget.isEdit ? '항목 수정' : '항목 추가',
          style: GoogleFonts.notoSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        if (widget.isEdit) ...[
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(null),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFFF6B6B),
                size: 20,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── 제목 입력 필드 ──
  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimeSectionLabel('일정명', Icons.event_note_rounded),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: TextField(
            controller: _titleCtrl,
            style: GoogleFonts.notoSans(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: '예) 브런치 카페, 점심 약속...',
              hintStyle: GoogleFonts.notoSans(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            cursorColor: _accent,
          ),
        ),
      ],
    );
  }

  // ── 섹션 레이블 ──
  Widget _buildTimeSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF9D8FFF)),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.notoSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF9D8FFF),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ── 드럼롤 시간 선택기 ──
  Widget _buildTimePicker({
    required FixedExtentScrollController hCtrl,
    required FixedExtentScrollController mCtrl,
    required ValueChanged<int> onHourChanged,
    required ValueChanged<int> onMinChanged,
  }) {
    const itemH = 44.0;
    const visibleCount = 3;
    const pickerH = itemH * visibleCount;

    return Container(
      height: pickerH,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // 시(hour)
          Expanded(
            child: _buildWheelColumn(
              controller: hCtrl,
              itemCount: 24,
              labelBuilder: (i) => '${i.toString().padLeft(2, '0')}시',
              onChanged: onHourChanged,
            ),
          ),

          // 구분선
          Container(
            width: 1,
            height: pickerH * 0.6,
            color: Colors.white.withValues(alpha: 0.1),
          ),

          // 분(minute) — 5분 단위
          Expanded(
            child: _buildWheelColumn(
              controller: mCtrl,
              itemCount: 12, // 0~55 (5분 단위)
              labelBuilder: (i) => '${(i * 5).toString().padLeft(2, '0')}분',
              onChanged: onMinChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheelColumn({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int) labelBuilder,
    required ValueChanged<int> onChanged,
  }) {
    const itemH = 44.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // 선택 영역 하이라이트
        Container(
          height: itemH,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _accent.withValues(alpha: 0.25),
            ),
          ),
        ),

        ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: itemH,
          diameterRatio: 1.8,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: itemCount,
            builder: (ctx, i) {
              return Center(
                child: Text(
                  labelBuilder(i),
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 종료 시간 토글 ──
  Widget _buildEndTimeToggle() {
    return GestureDetector(
      onTap: () => setState(() => _hasEndTime = !_hasEndTime),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _hasEndTime
              ? _accent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hasEndTime
                ? _accent.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _hasEndTime
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: _hasEndTime ? _accent : Colors.white38,
            ),
            const SizedBox(width: 10),
            _buildTimeSectionLabel('종료 시간 설정', Icons.stop_circle_outlined),
            const Spacer(),
            if (_hasEndTime)
              Text(
                _fmt(_endH, _endM),
                style: GoogleFonts.notoSans(
                  fontSize: 13,
                  color: const Color(0xFF9D8FFF),
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 색상 팔레트 ──
  Widget _buildColorPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: kPlanColors.map((c) {
        final isSelected = _selectedColor == c;
        final Color chipColor = c == null
            ? Colors.white24
            : Color(int.parse(c.substring(1, 7), radix: 16) + 0xFF000000);

        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => setState(() => _selectedColor = c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isSelected ? 42 : 36,
              height: isSelected ? 42 : 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: chipColor,
                border: isSelected
                    ? Border.all(color: Colors.white, width: 2.5)
                    : Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: chipColor.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                  : (c == null
                      ? const Icon(Icons.block_rounded, color: Colors.white38, size: 16)
                      : null),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── 액션 버튼 ──
  Widget _buildActionButtons() {
    return Row(
      children: [
        // 취소
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(null),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Center(
                child: Text(
                  '취소',
                  style: GoogleFonts.notoSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white60,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // 저장/추가
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _save,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9C6FE4)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isEdit
                          ? Icons.check_rounded
                          : Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isEdit ? '수정 완료' : '추가하기',
                      style: GoogleFonts.notoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
