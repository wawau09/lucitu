import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:glass_liquid_navbar/glass_liquid_navbar.dart';
import 'supabase_config.dart';

import 'package:placelist/Pages/map.dart';
import 'package:placelist/Pages/search.dart';
import 'Pages/main_page.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  if (!kIsWeb) {
    await FlutterNaverMap().init(
      clientId: '0w1sxphr42',
      onAuthFailed:
          (ex) => switch (ex) {
            NQuotaExceededException(:final message) => print(
              "사용량 초과 (message: $message)",
            ),
            NUnauthorizedClientException() ||
            NClientUnspecifiedException() ||
            NAnotherAuthFailedException() => print("인증 실패: $ex"),
          },
    );
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  final List<Widget> screens = [MapPage(), MainScreen(), SearchPage()];

  int _currentIndex = 1;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      home: PopScope(
        canPop: false,
        child: Scaffold(
          extendBody: true,
          backgroundColor: const Color(0xFFF8F5EF),

          body: IndexedStack(index: _currentIndex, children: screens),

          bottomNavigationBar: LiquidGlassNavbar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            activeColor: const Color(0xFF3267A2),
            items: [
              LiquidNavItem(
                icon: Icons.map_rounded,
                label: 'Map',
              ),
              LiquidNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
              ),
              LiquidNavItem(
                icon: Icons.search_rounded,
                label: 'Search',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
