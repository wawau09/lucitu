import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:placelist/providers/theme_provider.dart';

/// 동물 아바타 목록 (키: 저장 ID, 값: 이모지 + 한국어 이름)
const Map<String, Map<String, String>> animalAvatars = {
  'cat': {'emoji': '🐱', 'name': '고양이'},
  'dog': {'emoji': '🐶', 'name': '강아지'},
  'rabbit': {'emoji': '🐰', 'name': '토끼'},
  'fox': {'emoji': '🦊', 'name': '여우'},
  'panda': {'emoji': '🐼', 'name': '판다'},
  'bear': {'emoji': '🐻', 'name': '곰'},
  'penguin': {'emoji': '🐧', 'name': '펭귄'},
  'owl': {'emoji': '🦉', 'name': '부엉이'},
  'lion': {'emoji': '🦁', 'name': '사자'},
  'koala': {'emoji': '🐨', 'name': '코알라'},
  'unicorn': {'emoji': '🦄', 'name': '유니콘'},
  'tiger': {'emoji': '🐯', 'name': '호랑이'},
};

String getAvatarEmoji(String? key) {
  return animalAvatars[key]?['emoji'] ?? '🐱';
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final SupabaseClient _client = Supabase.instance.client;

  String _name = '';
  String _email = '';
  String _avatarIcon = 'cat';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final profile = await _client
          .from('profiles')
          .select('full_name, email, avatar_icon')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        _name = profile['full_name']?.toString() ?? '';
        _email = profile['email']?.toString() ?? user.email ?? '';
        _avatarIcon = profile['avatar_icon']?.toString() ?? 'cat';
      } else {
        final metadata = user.userMetadata;
        _name = metadata?['full_name']?.toString() ?? user.email?.split('@').first ?? '';
        _email = user.email ?? '';
        _avatarIcon = 'cat';
      }
    } catch (e) {
      final metadata = user.userMetadata;
      _name = metadata?['full_name']?.toString() ?? '';
      _email = user.email ?? '';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateName(String newName) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await _client.auth.updateUser(
        UserAttributes(data: {'full_name': newName}),
      );
      await _client.from('profiles').upsert({
        'id': user.id,
        'full_name': newName,
      });
      setState(() => _name = newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이름이 변경되었습니다.', style: GoogleFonts.notoSans()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: const Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이름 변경 실패: $e', style: GoogleFonts.notoSans()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateAvatar(String iconKey) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _avatarIcon = iconKey;
      _isSaving = true;
    });

    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        'avatar_icon': iconKey,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('프로필 아이콘이 변경되었습니다.', style: GoogleFonts.notoSans()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: const Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('아이콘 변경 실패: $e', style: GoogleFonts.notoSans()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showChangeNameDialog() {
    final controller = TextEditingController(text: _name);
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A90E2), Color(0xFF6C63FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('✏️', style: TextStyle(fontSize: 28)),
                          const SizedBox(height: 10),
                          Text(
                            '이름 변경',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '새로운 이름',
                            style: GoogleFonts.notoSansKr(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: errorText != null
                                    ? Colors.redAccent
                                    : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                              ),
                            ),
                            child: TextField(
                              controller: controller,
                              maxLength: 20,
                              style: GoogleFonts.notoSansKr(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: '이름을 입력해주세요',
                                hintStyle: GoogleFonts.notoSansKr(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                ),
                                prefixIcon: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                                border: InputBorder.none,
                                counterText: '',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              onChanged: (_) {
                                if (errorText != null) setDialogState(() => errorText = null);
                              },
                            ),
                          ),
                          if (errorText != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              errorText!,
                              style: GoogleFonts.notoSansKr(fontSize: 12, color: Colors.redAccent),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text('취소', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: () {
                                final newName = controller.text.trim();
                                if (newName.isEmpty) {
                                  setDialogState(() => errorText = '이름을 입력해주세요.');
                                  return;
                                }
                                Navigator.pop(dialogContext);
                                _updateName(newName);
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text('저장', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
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

  void _showAvatarPicker() {
    String tempSelection = _avatarIcon;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '프로필 아이콘 선택',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '마음에 드는 동물 아이콘을 선택하세요',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Preview
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: CircleAvatar(
                          key: ValueKey(tempSelection),
                          radius: 40,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            getAvatarEmoji(tempSelection),
                            style: const TextStyle(fontSize: 40),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: animalAvatars.length,
                        itemBuilder: (context, index) {
                          final entry = animalAvatars.entries.elementAt(index);
                          final isSelected = tempSelection == entry.key;
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() => tempSelection = entry.key);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(entry.value['emoji']!, style: const TextStyle(fontSize: 28)),
                                  const SizedBox(height: 4),
                                  Text(
                                    entry.value['name']!,
                                    style: GoogleFonts.notoSansKr(
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _updateAvatar(tempSelection);
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('선택 완료', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
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
  }

  Future<void> _handleSignOut() async {
    await _client.auth.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _handleDeleteAccount() async {
    // 1단계: 경고
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 48),
        title: Text('회원 탈퇴', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold)),
        content: Text(
          '회원 탈퇴 시 계정과 모든 데이터가 삭제되며 복구할 수 없습니다.\n\n정말 탈퇴하시겠습니까?',
          style: GoogleFonts.notoSansKr(height: 1.5),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text('탈퇴하기', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

    // 2단계: 최종 확인
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('최종 확인', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        content: Text(
          '이 작업은 되돌릴 수 없습니다.\n계속 진행하시겠습니까?',
          style: GoogleFonts.notoSansKr(height: 1.5),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('돌아가기', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text('영구 삭제', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );

    if (secondConfirm != true || !mounted) return;

    // 3단계: 실제 삭제
    setState(() => _isLoading = true);
    try {
      await _client.rpc('delete_user_account');
      await _client.auth.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('계정이 삭제되었습니다.', style: GoogleFonts.notoSans()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('회원 탈퇴 실패: $e', style: GoogleFonts.notoSans()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('설정', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // ── 프로필 영역 ──
                _buildProfileCard(colorScheme),
                const SizedBox(height: 16),

                // ── 프로필 편집 ──
                _buildSectionCard(
                  title: '프로필 관리',
                  icon: Icons.person_outline,
                  children: [
                    _buildSettingsTile(
                      icon: Icons.edit_outlined,
                      title: '이름 변경',
                      subtitle: _name,
                      onTap: _showChangeNameDialog,
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildSettingsTile(
                      icon: Icons.face_outlined,
                      title: '프로필 아이콘 변경',
                      subtitle: '동물 아이콘 선택',
                      trailing: Text(getAvatarEmoji(_avatarIcon), style: const TextStyle(fontSize: 24)),
                      onTap: _showAvatarPicker,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 테마 설정 ──
                _buildSectionCard(
                  title: '테마 설정',
                  icon: Icons.palette_outlined,
                  children: [
                    _buildThemeRadio(
                      title: '시스템 설정 사용',
                      subtitle: '기기의 테마 설정을 따릅니다',
                      value: ThemeMode.system,
                      groupValue: themeMode,
                      icon: Icons.phone_android_outlined,
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildThemeRadio(
                      title: '라이트 모드',
                      subtitle: '밝은 테마를 사용합니다',
                      value: ThemeMode.light,
                      groupValue: themeMode,
                      icon: Icons.light_mode_outlined,
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildThemeRadio(
                      title: '다크 모드',
                      subtitle: '어두운 테마를 사용합니다',
                      value: ThemeMode.dark,
                      groupValue: themeMode,
                      icon: Icons.dark_mode_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 계정 관리 ──
                _buildSectionCard(
                  title: '계정',
                  icon: Icons.manage_accounts_outlined,
                  children: [
                    _buildSettingsTile(
                      icon: Icons.logout_outlined,
                      title: '로그아웃',
                      subtitle: '현재 계정에서 로그아웃합니다',
                      onTap: _handleSignOut,
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildSettingsTile(
                      icon: Icons.delete_forever_outlined,
                      title: '회원 탈퇴',
                      subtitle: '계정과 모든 데이터를 영구 삭제합니다',
                      titleColor: Colors.redAccent,
                      onTap: _handleDeleteAccount,
                    ),
                  ],
                ),
                const SizedBox(height: 60),
              ],
            ),
    );
  }

  Widget _buildProfileCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    getAvatarEmoji(_avatarIcon),
                    style: const TextStyle(fontSize: 44),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _showAvatarPicker,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.edit, size: 14, color: colorScheme.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isSaving)
              const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else ...[
              GestureDetector(
                onTap: _showChangeNameDialog,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _name.isEmpty ? '이름 없음' : _name,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.edit_outlined, size: 16, color: colorScheme.primary),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _email,
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: titleColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(
        title,
        style: GoogleFonts.notoSansKr(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.notoSansKr(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      trailing: trailing ?? Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outlineVariant),
      onTap: onTap,
    );
  }

  Widget _buildThemeRadio({
    required String title,
    required String subtitle,
    required ThemeMode value,
    required ThemeMode groupValue,
    required IconData icon,
  }) {
    final isSelected = value == groupValue;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(
        title,
        style: GoogleFonts.notoSansKr(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.notoSansKr(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      trailing: Radio<ThemeMode>(
        value: value,
        groupValue: groupValue,
        onChanged: (v) {
          if (v != null) ref.read(themeProvider.notifier).setTheme(v);
        },
      ),
      onTap: () => ref.read(themeProvider.notifier).setTheme(value),
    );
  }
}
