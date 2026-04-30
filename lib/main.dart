import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

          bottomNavigationBar: Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: BottomNavigationBar(
                    currentIndex: _currentIndex,
                    showSelectedLabels: false,
                    showUnselectedLabels: false,
                    backgroundColor: Colors.transparent,
                    selectedItemColor: const Color(0xFF3267A2),
                    unselectedItemColor: Colors.black.withOpacity(0.3),
                    iconSize: 28,
                    elevation: 0,
                    type: BottomNavigationBarType.fixed,
                    onTap: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.map_rounded),
                        label: 'Map',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home_rounded),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.search_rounded),
                        label: 'Search',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
