import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:placelist/Pages/map.dart';
import 'package:placelist/Pages/search.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'Pages/main_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  await Supabase.initialize(
    url: "https://mgebziaamxgrhudurklz.supabase.co",
    anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1nZWJ6aWFhbXhncmh1ZHVya2x6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk1MzU5MjUsImV4cCI6MjA2NTExMTkyNX0.mKMtBL4j2wQwO7FR-2OWtjthxzfiYNuGGEqpmYr3QCM"
  );

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  final List<Widget> screens = [
    MapPage(),
    MainPage(),
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
          centerTitle: true,
          title: const Text("Placelist"),
          titleTextStyle: TextStyle(
            fontSize: 35,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        body: screens[screenIndex],
        
        bottomNavigationBar: SalomonBottomBar(
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
          }
        ),
      ),
    );
  }
}