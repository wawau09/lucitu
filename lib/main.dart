import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'supabase_config.dart';
import 'package:placelist/Pages/account.dart';
import 'package:placelist/Pages/plan_page.dart';
import 'package:placelist/Pages/terms_agreement_page.dart';
import 'Pages/main_page.dart';
import 'package:placelist/providers/navigation_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:placelist/providers/theme_provider.dart';
import 'package:placelist/utils/app_colors.dart';

ValueNotifier<String?> naverMapAuthErrorNotifier = ValueNotifier<String?>(null);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    final info = await PackageInfo.fromPlatform();
    await FlutterNaverMap().init(
      clientId: naverMapClientId,
      onAuthFailed: (error) {
        debugPrint('Naver Map Auth Failed: $error');
        naverMapAuthErrorNotifier.value =
            '$error\n📌 내 앱의 실제 Bundle ID: ${info.packageName}';
      },
    );
  }

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
  StreamSubscription<AuthState>? _authSub;

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
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
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

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
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
    final themeMode = ref.watch(themeProvider);
    final List<Widget> screens = [const PlanPage(), const MainScreen(), const AccountPage()];

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      navigatorObservers: kIsWeb ? [] : [CNTabBarRouteObserver()],
      themeMode: themeMode,
      theme: ThemeData(
        fontFamily: 'Pretendard',
        fontFamilyFallback: const ['Noto Sans KR', 'sans-serif'],
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.backgroundLight,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surfaceLight,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: AppColors.backgroundLight,
          surfaceContainer: const Color(0xFFF2F3F5),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.backgroundLight,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontFamily: 'Pretendard',
            color: AppColors.textPrimaryLight,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: AppColors.textPrimaryLight),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.surfaceLight,
          surfaceTintColor: Colors.transparent,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: AppColors.borderLight,
              width: 1,
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          backgroundColor: AppColors.backgroundLight,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.primaryContainer,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.primary,
              );
            }
            return const TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.normal,
              fontSize: 12,
              color: AppColors.textSecondaryLight,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.primary);
            }
            return const IconThemeData(color: AppColors.textSecondaryLight);
          }),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceLight,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.borderLight,
          thickness: 1,
          space: 1,
        ),
      ),
      darkTheme: ThemeData(
        fontFamily: 'Pretendard',
        fontFamilyFallback: const ['Noto Sans KR', 'sans-serif'],
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundDark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.accentLight,
          surface: AppColors.surfaceDark,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.backgroundDark,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.surfaceDark,
          surfaceTintColor: Colors.transparent,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: AppColors.borderDark,
              width: 1,
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          backgroundColor: AppColors.backgroundDark,
          surfaceTintColor: Colors.transparent,
          indicatorColor: Colors.white.withOpacity(0.12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.accentLight,
            foregroundColor: AppColors.backgroundDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceDark,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.borderDark,
          thickness: 1,
          space: 1,
        ),
      ),
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox(),
            ValueListenableBuilder<String?>(
              valueListenable: naverMapAuthErrorNotifier,
              builder: (context, authError, _) {
                if (authError == null) return const SizedBox();
                return SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '🚨 네이버 지도 인증 실패 (iOS Log)',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(
                                    'Error: $authError\nClient ID: ${kIsWeb ? naverMapWebClientId : naverMapClientId}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => naverMapAuthErrorNotifier.value = null,
                              child: const Icon(Icons.close, color: Colors.white70, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
      home: PopScope(
        canPop: false,
        child: Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Scaffold(
              extendBody: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: IndexedStack(index: currentIndex, children: screens),
              bottomNavigationBar: _buildCompactBottomBar(
                context: context,
                currentIndex: currentIndex,
                onTap: (index) =>
                    ref.read(navigationProvider.notifier).setIndex(index),
                isDark: isDark,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactBottomBar({
    required BuildContext context,
    required int currentIndex,
    required ValueChanged<int> onTap,
    required bool isDark,
  }) {
    final items = [
      (Icons.calendar_today_outlined, Icons.calendar_today_rounded),
      (Icons.home_outlined, Icons.home_rounded),
      (Icons.person_outline_rounded, Icons.person_rounded),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final isSelected = currentIndex == index;
              final (unselectedIcon, selectedIcon) = items[index];

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                ? AppColors.accentLight.withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.1))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isSelected ? selectedIcon : unselectedIcon,
                        size: 22,
                        color: isSelected
                            ? (isDark ? AppColors.accentLight : AppColors.primary)
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

