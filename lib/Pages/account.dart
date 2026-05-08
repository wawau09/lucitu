import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  User? _user;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _user = Supabase.instance.client.auth.currentUser;
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _user = data.session?.user;
        });
      }
    });
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // google_sign_in을 사용하지 않고 Supabase의 signInWithOAuth를 직접 사용합니다.
      // 이 방식은 Supabase 대시보드에 구글 클라이언트 ID와 시크릿이 설정되어 있어야 합니다.
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        // Uri.base.origin을 사용하여 현재 도메인(Vercel 또는 localhost)으로 자동 리디렉션되도록 합니다.
        redirectTo: kIsWeb ? Uri.base.origin : 'io.supabase.placelist://login-callback',
      );

    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _user == null ? _buildLoggedOutView() : _buildLoggedInView(),
      ),
    );
  }

  Widget _buildLoggedOutView() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.account_circle_outlined,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                "로그인이 필요합니다",
                style: GoogleFonts.notoSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "즐겨찾는 카페를 저장하려면 로그인하세요.",
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _handleGoogleSignIn,
                    icon: const Icon(Icons.login, size: 20),
                    label: Text(
                      "구글로 로그인",
                      style: GoogleFonts.notoSans(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
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

  Widget _buildLoggedInView() {
    final metadata = _user!.userMetadata;
    final String name = metadata?['full_name'] ?? _user!.email ?? '사용자';
    final String? avatarUrl = metadata?['avatar_url'];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          CircleAvatar(
            radius: 50,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null ? const Icon(Icons.person, size: 50) : null,
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: GoogleFonts.notoSans(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _user!.email ?? '',
            style: GoogleFonts.notoSans(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 40),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text("내가 찜한 카페"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 찜한 카페 목록 페이지 이동
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text("설정"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Spacer(),
          TextButton(
            onPressed: _handleSignOut,
            child: Text(
              "로그아웃",
              style: GoogleFonts.notoSans(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
