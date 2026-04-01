import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dot_navigation_bar/dot_navigation_bar.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

import 'package:placelist/Pages/map.dart';
import 'package:placelist/Pages/search.dart';
import 'Pages/main_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  if (!kIsWeb) {
    await FlutterNaverMap().init(
        clientId: '0w1sxphr42',
        onAuthFailed: (ex) => switch (ex) {
              NQuotaExceededException(:final message) =>
                print("사용량 초과 (message: $message)"),
              NUnauthorizedClientException() ||
              NClientUnspecifiedException() ||
              NAnotherAuthFailedException() =>
                print("인증 실패: $ex"),
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  final List<Widget> screens = [
    MapPage(),
    MainScreen(),
    SearchPage(),
  ];

  int _currentIndex = 1;
  bool _bottomBarVisible = true;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        extendBody: true,
        backgroundColor: Colors.white,
        appBar: AppBar(
          toolbarHeight: 50,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          centerTitle: true,
          title: const Text("Placelist"),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 35,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        body: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            final direction = notification.direction;
            if (direction == ScrollDirection.reverse && _bottomBarVisible) {
              setState(() => _bottomBarVisible = false);
            } else if (direction == ScrollDirection.forward &&
                !_bottomBarVisible) {
              setState(() => _bottomBarVisible = true);
            }
            return false;
          },
          child: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
        ),
        
        bottomNavigationBar: AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          offset: _bottomBarVisible ? Offset.zero : const Offset(0, 1.5),
          curve: Curves.easeInOutCubic,
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: DotNavigationBar(
              currentIndex: _currentIndex,
              marginR: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              paddingR: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: Colors.white,
              dotIndicatorColor: Colors.black, // Default dot color for visual accent
              items: [
                DotNavigationBarItem(
                  icon: const Icon(Icons.workspaces, size: 28),
                  selectedColor: Colors.lightBlue,
                  unselectedColor: Colors.grey,
                ),
                DotNavigationBarItem(
                  icon: const Icon(Icons.home, size: 28),
                  selectedColor: Colors.lightBlue,
                  unselectedColor: Colors.grey,
                ),
                DotNavigationBarItem(
                  icon: const Icon(Icons.search, size: 28),
                  selectedColor: Colors.lightBlue,
                  unselectedColor: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}