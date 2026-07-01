import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'supabase_config.dart';
import 'package:placelist/Pages/account.dart';
import 'package:placelist/Pages/search.dart';
import 'package:placelist/Pages/terms_agreement_page.dart';
import 'Pages/main_page.dart';
import 'package:placelist/providers/navigation_provider.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterNaverMap().init(
    clientId: 'lpx588w5up',
    onAuthFailed: (error) {
      debugPrint('Naver Map Auth Failed: $error');
    },
  );

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const ProviderScope(child: MyApp()));
}

/// 앱 전역에서 사용할 navigatorKey
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _isShowingTerms = false;

  @override
  void initState() {
    super.initState();

    // 앱 시작 시 이미 로그인된 사용자의 약관 동의 여부 확인
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkTermsAgreement(currentUser);
      });
    }

    // 로그인 상태 변경 감지 (OAuth 리다이렉트 후 포함)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        // 약간의 딜레이를 줘서 앱이 완전히 준비된 후 실행
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _checkTermsAgreement(user);
          }
        });
      }
    });
  }

  /// 사용자가 약관에 동의했는지 확인하고, 미동의 시 약관 동의 시트를 표시합니다.
  Future<void> _checkTermsAgreement(User user) async {
    final termsAgreed = user.userMetadata?['terms_agreed'] == true;
    if (termsAgreed || _isShowingTerms) return;

    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    _isShowingTerms = true;

    final name = await showTermsAgreementSheet(ctx);

    if (name != null && name.isNotEmpty) {
      // 동의함 → user_metadata에 기록 및 profiles 테이블에 저장
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'terms_agreed': true, 'full_name': name}),
        );
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'email': user.email ?? '',
          'full_name': name,
        });
      } catch (e) {
        debugPrint('약관 동의 메타데이터 업데이트 실패: $e');
      }
    } else {
      // 동의하지 않음 → 로그아웃
      await Supabase.instance.client.auth.signOut();
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              '약관에 동의해야 서비스를 이용할 수 있습니다.',
              style: GoogleFonts.notoSans(),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }

    _isShowingTerms = false;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationProvider);
    final List<Widget> screens = [const PlanPage(), const MainScreen(), const AccountPage()];

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [CNTabBarRouteObserver()],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorSchemeSeed: const Color(0xFF3267A2),
      ),
      home: PopScope(
        canPop: false,
        child: Scaffold(
          extendBody: true,
          backgroundColor: Colors.white,
          body: IndexedStack(index: currentIndex, children: screens),
          bottomNavigationBar: CNTabBar(
            currentIndex: currentIndex,
            onTap: (index) => ref.read(navigationProvider.notifier).setIndex(index),
            tint: const Color(0xFF3267A2),
            items: const [
              CNTabBarItem(
                label: '일정',
                icon: CNSymbol('calendar'),
                activeIcon: CNSymbol('calendar'),
              ),
              CNTabBarItem(
                label: '홈',
                icon: CNSymbol('house'),
                activeIcon: CNSymbol('house.fill'),
              ),
              CNTabBarItem(
                label: '계정',
                icon: CNSymbol('person'),
                activeIcon: CNSymbol('person.fill'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

