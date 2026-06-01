import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class PlanPage extends ConsumerStatefulWidget {
  const PlanPage({super.key});

  @override
  ConsumerState<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends ConsumerState<PlanPage> {
  final TextEditingController _planNameController =
      TextEditingController(text: '\uC8FC\uB9D0 \uCE74\uD398 \uD22C\uC5B4');

  final List<_TimelineItem> _timeline = const [
    _TimelineItem(time: '09:30', title: '\uCD9C\uBC1C', subtitle: '\uC9D1\uC5D0\uC11C \uCD9C\uBC1C'),
    _TimelineItem(time: '10:20', title: '1\uBC88 \uC7A5\uC18C', subtitle: '\uBE0C\uB7F0\uCE58 \uCE74\uD398'),
    _TimelineItem(time: '12:10', title: '2\uBC88 \uC7A5\uC18C', subtitle: '\uC911\uAC04\uC5D0 \uB4E4\uB9B4 \uC804\uC2DC \uACF5\uAC04'),
    _TimelineItem(time: '15:00', title: '\uB9C8\uBB34\uB9AC', subtitle: '\uC0B0\uCC45 \uD6C4 \uBCF5\uADC0'),
  ];

  final List<String> _stopPlaces = const [
    '\uBE0C\uB7F0\uCE58 \uCE74\uD398',
    '\uC804\uC2DC \uACF5\uAC04',
    '\uB514\uC800\uD2B8 \uB9E4\uC7A5',
  ];

  String get _planCode {
    final name = _planNameController.text.trim();
    final slug = name.isEmpty
        ? 'PLAN'
        : name.replaceAll(RegExp(r'\s+'), '-').toUpperCase();
    return 'PL-$slug-260602';
  }

  @override
  void dispose() {
    _planNameController.dispose();
    super.dispose();
  }

  Future<void> _copyPlanCode() async {
    await Clipboard.setData(ClipboardData(text: _planCode));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '\uACC4\uD68D \uCF54\uB4DC\uAC00 \uBCF5\uC0AC\uB418\uC5C8\uC2B5\uB2C8\uB2E4: $_planCode',
          style: GoogleFonts.notoSans(),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _formatDate(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EE),
      body: SafeArea(
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF6F3EE), Color(0xFFFFFFFF)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionCard(
                        title: '\uC77C\uC815',
                        icon: Icons.event_note_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '\uC624\uB298 \uACC4\uD68D\uC744 \uD55C\uB208\uC5D0 \uC815\uB9AC\uD574\uC694',
                              style: GoogleFonts.notoSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildScheduleSummary(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildSectionCard(
                        title: '\uC911\uAC04\uC5D0 \uB4E4\uB9B4 \uC7A5\uC18C',
                        icon: Icons.place_rounded,
                        child: Column(
                          children: _stopPlaces
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
                      _buildSectionCard(
                        title: '\uC2DC\uAC04\uBCC4',
                        icon: Icons.schedule_rounded,
                        child: Column(
                          children: _timeline
                              .map(
                                (item) => _TimelineRow(item: item),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE7E0D8)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              dateText,
                              style: GoogleFonts.notoSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _copyPlanCode,
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              label: const Text('\uCF54\uB4DC \uBCF5\uC0AC'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3267A2),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: GoogleFonts.notoSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _planCode,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.notoSans(
                                fontSize: 12,
                                color: const Color(0xFF6B7280),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D5D92), Color(0xFF78A6D1)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2D5D92).withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '\uACC4\uD68D \uC774\uB984',
              style: GoogleFonts.notoSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _planNameController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.notoSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: '\uC0C8 \uACC4\uD68D\uC744 \uC785\uB825\uD558\uC138\uC694',
                hintStyle: GoogleFonts.notoSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF3267A2).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF3267A2), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.notoSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildScheduleSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          _buildSummaryItem(label: '\uC77C\uC815 \uC218', value: '${_timeline.length}\uAC1C'),
          Container(width: 1, height: 40, color: const Color(0xFFE5E7EB)),
          _buildSummaryItem(label: '\uB4E4\uB9B4 \uACF3', value: '${_stopPlaces.length}\uACF3'),
          Container(width: 1, height: 40, color: const Color(0xFFE5E7EB)),
          _buildSummaryItem(label: '\uCF54\uB4DC', value: '\uBCF5\uC0AC \uAC00\uB2A5'),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({required String label, required String value}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.notoSans(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.notoSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceChip(String place) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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

  String _formatDate(DateTime date) {
    const weekDays = ['\uC77C', '\uC6D4', '\uD654', '\uC218', '\uBAA9', '\uAE08', '\uD1A0'];
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} (${weekDays[date.weekday % 7]})';
  }
}

class _TimelineItem {
  const _TimelineItem({
    required this.time,
    required this.title,
    required this.subtitle,
  });

  final String time;
  final String title;
  final String subtitle;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item});

  final _TimelineItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              item.time,
              style: GoogleFonts.notoSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF3267A2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 12,
            height: 12,
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
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB)),
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
                    item.subtitle,
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
}
