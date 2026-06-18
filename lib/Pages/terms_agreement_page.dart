import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsAgreementSheet extends StatefulWidget {
  const TermsAgreementSheet({super.key});

  @override
  State<TermsAgreementSheet> createState() => _TermsAgreementSheetState();
}

class _TermsAgreementSheetState extends State<TermsAgreementSheet>
    with SingleTickerProviderStateMixin {
  bool _agreeAll = false;
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _termsExpanded = false;
  bool _privacyExpanded = false;

  late AnimationController _buttonAnimController;
  late Animation<double> _buttonScaleAnim;
  
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _buttonAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _buttonScaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonAnimController, curve: Curves.easeInOut),
    );
    _nameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _buttonAnimController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _allAgreed => _agreeTerms && _agreePrivacy;
  bool get _canSubmit => _allAgreed && _nameController.text.trim().isNotEmpty;

  void _toggleAll(bool? value) {
    setState(() {
      _agreeAll = value ?? false;
      _agreeTerms = _agreeAll;
      _agreePrivacy = _agreeAll;
    });
  }

  void _updateAgreeAll() {
    setState(() {
      _agreeAll = _agreeTerms && _agreePrivacy;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3267A2).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFF3267A2),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '약관 동의',
                        style: GoogleFonts.notoSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '서비스 이용을 위해 약관에 동의해주세요',
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Agree All
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: InkWell(
              onTap: () => _toggleAll(!_agreeAll),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _agreeAll
                      ? const Color(0xFF3267A2).withValues(alpha: 0.08)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _agreeAll
                        ? const Color(0xFF3267A2).withValues(alpha: 0.3)
                        : Colors.grey[200]!,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _agreeAll
                            ? const Color(0xFF3267A2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: _agreeAll
                              ? const Color(0xFF3267A2)
                              : Colors.grey[350]!,
                          width: 2,
                        ),
                      ),
                      child: _agreeAll
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '전체 동의합니다',
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _agreeAll
                            ? const Color(0xFF3267A2)
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Name Input Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '사용할 이름 (닉네임)',
                labelStyle: GoogleFonts.notoSans(color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF3267A2), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: GoogleFonts.notoSans(fontSize: 15, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 12),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Terms of Service
                  _buildAgreementItem(
                    title: '이용약관 동의',
                    required: true,
                    isAgreed: _agreeTerms,
                    isExpanded: _termsExpanded,
                    onChanged: (val) {
                      setState(() {
                        _agreeTerms = val ?? false;
                        _updateAgreeAll();
                      });
                    },
                    onExpandToggle: () {
                      setState(() => _termsExpanded = !_termsExpanded);
                    },
                    content: _termsOfServiceText,
                  ),
                  const SizedBox(height: 8),

                  // Privacy Policy
                  _buildAgreementItem(
                    title: '개인정보 처리방침 동의',
                    required: true,
                    isAgreed: _agreePrivacy,
                    isExpanded: _privacyExpanded,
                    onChanged: (val) {
                      setState(() {
                        _agreePrivacy = val ?? false;
                        _updateAgreeAll();
                      });
                    },
                    onExpandToggle: () {
                      setState(() => _privacyExpanded = !_privacyExpanded);
                    },
                    content: _privacyPolicyText,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Bottom button area
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 34),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: GestureDetector(
              onTapDown: _canSubmit
                  ? (_) => _buttonAnimController.forward()
                  : null,
              onTapUp: _canSubmit
                  ? (_) {
                      _buttonAnimController.reverse();
                      Navigator.pop(context, _nameController.text.trim());
                    }
                  : null,
              onTapCancel: _canSubmit
                  ? () => _buttonAnimController.reverse()
                  : null,
              child: ScaleTransition(
                scale: _buttonScaleAnim,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: _canSubmit
                        ? const LinearGradient(
                            colors: [Color(0xFF3267A2), Color(0xFF4A8BD4)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: _canSubmit ? null : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _canSubmit
                        ? [
                            BoxShadow(
                              color: const Color(0xFF3267A2).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '동의하고 계속하기',
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _canSubmit ? Colors.white : Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementItem({
    required String title,
    required bool required,
    required bool isAgreed,
    required bool isExpanded,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onExpandToggle,
    required String content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAgreed
              ? const Color(0xFF3267A2).withValues(alpha: 0.2)
              : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => onChanged(!isAgreed),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isAgreed
                          ? const Color(0xFF3267A2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isAgreed
                            ? const Color(0xFF3267A2)
                            : Colors.grey[350]!,
                        width: 1.5,
                      ),
                    ),
                    child: isAgreed
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  if (required)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '필수',
                        style: GoogleFonts.notoSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE53935),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.notoSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onExpandToggle,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey[400],
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    content,
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      height: 1.8,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

// ----- 약관 텍스트 -----

const String _termsOfServiceText = '''
제 1조 (목적)
본 약관은 플레이스리스트(이하 "서비스")의 이용조건 및 절차, 이용자와 서비스 제공자의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.

제 2조 (정의)
① "서비스"란 회사가 제공하는 카페 정보 탐색, 즐겨찾기 저장 등 관련 제반 서비스를 의미합니다.
② "이용자"란 본 약관에 따라 서비스를 이용하는 자를 말합니다.
③ "회원"이란 서비스에 가입하여 계정을 생성한 이용자를 말합니다.

제 3조 (약관의 효력과 변경)
① 본 약관은 서비스를 이용하고자 하는 모든 이용자에 대하여 그 효력을 발생합니다.
② 회사는 필요한 경우 약관을 변경할 수 있으며, 변경된 약관은 서비스 내 공지사항을 통해 공지합니다.

제 4조 (서비스의 제공)
① 회사는 다음과 같은 서비스를 제공합니다:
  - 카페 정보 검색 및 조회
  - 카페 즐겨찾기(찜) 기능
  - 지도 기반 카페 위치 확인
  - 카페 상세 정보 열람
② 서비스는 연중무휴, 1일 24시간 제공함을 원칙으로 합니다.

제 5조 (이용자의 의무)
① 이용자는 다음 행위를 하여서는 안 됩니다:
  - 타인의 정보 도용
  - 서비스에 게시된 정보의 무단 변경
  - 서비스의 운영을 방해하는 행위
  - 기타 법령에 위반되는 행위

제 6조 (서비스 이용의 제한)
회사는 이용자가 본 약관의 의무를 위반하거나 서비스의 정상적인 운영을 방해한 경우, 서비스 이용을 제한할 수 있습니다.

제 7조 (면책조항)
① 회사는 천재지변, 전쟁 등 불가항력으로 인하여 서비스를 제공할 수 없는 경우에는 책임이 면제됩니다.
② 회사는 이용자의 귀책사유로 인한 서비스 이용의 장애에 대하여 책임을 지지 않습니다.
③ 서비스에 게시된 카페 정보는 참고용이며, 실제와 다를 수 있습니다.
''';

const String _privacyPolicyText = '''
1. 개인정보의 수집 및 이용 목적
회사는 다음의 목적을 위하여 개인정보를 처리합니다:
  - 회원 가입 및 관리: 회원제 서비스 이용에 따른 본인확인, 개인 식별
  - 서비스 제공: 카페 즐겨찾기 저장, 맞춤형 서비스 제공
  - 서비스 개선: 서비스 이용 통계 분석, 서비스 품질 향상

2. 수집하는 개인정보의 항목
회사는 서비스 제공을 위해 다음과 같은 개인정보를 수집합니다:
  - 필수 항목: 이메일 주소, 이름(닉네임), 프로필 사진 URL
  - 자동 수집 항목: 서비스 이용 기록, 접속 로그, 접속 IP 정보

3. 개인정보의 보유 및 이용 기간
① 회원 탈퇴 시까지 보유합니다.
② 단, 관련 법령에 따라 보존할 필요가 있는 경우 해당 기간 동안 보관합니다:
  - 계약 또는 청약철회 등에 관한 기록: 5년
  - 소비자 불만 또는 분쟁 처리에 관한 기록: 3년
  - 접속 기록: 3개월

4. 개인정보의 파기 절차 및 방법
① 파기 절차: 이용 목적이 달성된 개인정보는 별도의 DB로 옮겨져 내부 방침에 따라 일정 기간 저장된 후 파기됩니다.
② 파기 방법: 전자적 파일 형태의 정보는 복구할 수 없는 기술적 방법을 사용하여 삭제합니다.

5. 개인정보의 제3자 제공
회사는 이용자의 개인정보를 원칙적으로 외부에 제공하지 않습니다. 다만, 다음의 경우에는 예외로 합니다:
  - 이용자가 사전에 동의한 경우
  - 법령의 규정에 의거하거나, 수사 목적으로 법령에 정해진 절차와 방법에 따라 수사기관의 요구가 있는 경우

6. 이용자의 권리와 행사 방법
이용자는 언제든지 자신의 개인정보를 조회하거나 수정할 수 있으며, 회원 탈퇴를 통해 개인정보의 처리 정지를 요청할 수 있습니다.

7. 개인정보 보호책임자
개인정보 처리에 관한 업무를 총괄해서 책임지고, 관련 불만 처리 및 피해 구제를 위하여 개인정보 보호책임자를 지정하고 있습니다.

8. 개인정보 처리방침 변경
본 개인정보 처리방침은 시행일로부터 적용되며, 변경사항이 있는 경우 서비스 내 공지를 통해 안내합니다.
''';

/// 약관 동의 바텀시트를 표시하고, 닉네임과 함께 결과를 반환합니다.
/// 동의하면 입력된 닉네임(String), 취소/닫으면 null을 반환합니다.
Future<String?> showTermsAgreementSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const TermsAgreementSheet(),
  );
}
