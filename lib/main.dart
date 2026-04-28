import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';


import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

import 'package:placelist/Pages/map.dart';
import 'package:placelist/Pages/search.dart';
import 'Pages/main_page.dart';

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

  // This widget is the root of your application.
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
          backgroundColor: Colors.white,

          body: IndexedStack(index: _currentIndex, children: screens),

          bottomNavigationBar: Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.of(context).padding.bottom + 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      spreadRadius: 0,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Theme(
                    data: ThemeData(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: BottomNavigationBar(
                      currentIndex: _currentIndex,
                      showSelectedLabels: false,
                      showUnselectedLabels: false,
                      backgroundColor: Colors.white,
                      selectedItemColor: Colors.lightBlue,
                      unselectedItemColor: Colors.grey,
                      iconSize: 30,
                      elevation: 0,
                      type: BottomNavigationBarType.fixed,
                      onTap: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.workspaces),
                          label: 'Map',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.home),
                          label: 'Home',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.search),
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
