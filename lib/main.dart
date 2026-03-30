import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
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

  int screenIndex = 1;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          toolbarHeight: 50,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
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

        body: screens[screenIndex],
        
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SalomonBottomBar(
            currentIndex: screenIndex,
            backgroundColor: Colors.white,
            selectedItemColor: Colors.lightBlue,
            unselectedItemColor: Colors.grey,
            items: [
              SalomonBottomBarItem(icon: Icon(Icons.workspaces),title: Text("MAP"), selectedColor: Colors.black,),
              SalomonBottomBarItem(icon: Icon(Icons.home), title: Text("HOME"), selectedColor: Colors.black,),
              SalomonBottomBarItem(icon: Icon(Icons.search), title: Text("SEARCH"), selectedColor: Colors.black,),
            ],
            onTap: (index) {
              setState(() {
                screenIndex = index;
              });
            },
          ),
        ),
      ),
    );
  }
}