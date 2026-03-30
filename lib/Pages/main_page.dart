import 'package:flutter/material.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/DB/store_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => Main();
}

class Main extends State<MainPage> {
  final storesDatabase = StoreDatabase();

  // Firebase Storage에서 이미지 URL을 가져오는 함수
  Future<String> getImageUrl(String folder, String imageName) async {
    try {
      // Storage 경로: 폴더명/파일명.jpeg
      final ref = FirebaseStorage.instance.ref().child('$folder/$imageName.jpeg');
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("이미지 로드 실패: $e");
      return ""; // 실패 시 빈 문자열 반환
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Center(
        child: Text('검색 기능 개발 진행중', style: TextStyle(fontSize: 16)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.all(8.0)),
          StreamBuilder<List<Store>>(
            stream: storesDatabase.stream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 250,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final stores = snapshot.data!;

              return SizedBox(
                height: 280, // 텍스트 영역을 고려해 높이 상향 조절
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  scrollDirection: Axis.horizontal,
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    // index 대신 데이터 객체를 직접 전달
                    return buildCard(stores[index]);
                  },
                ),
              );
            },
          )
        ],
      ),
    );
  }

  // 이제 Store 객체를 직접 받아서 화면을 그립니다.
  Widget buildCard(Store store) => Container(
        width: 200,
        margin: const EdgeInsets.only(right: 15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: FutureBuilder<String>(
                // store 객체에 이미 들어있는 folderName을 사용합니다.
                future: getImageUrl(store.folderName, "1"),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported),
                    );
                  }

                  return Image.network(
                    snapshot.data!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // 별도의 FutureBuilder 없이 store.name을 바로 사용!
            Text(
              store.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}