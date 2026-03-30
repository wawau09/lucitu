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
      width: 220,
      margin: const EdgeInsets.only(right: 20, bottom: 10), // 카드 사이 간격
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24), // 더 둥근 모서리
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // 텍스트 왼쪽 정렬
        children: [
          // 1. 이미지 영역 (상단 곡률 유지)
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: FutureBuilder<String>(
                  future: getImageUrl(store.folderName, "1"),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Container(
                        height: 180,
                        color: Colors.grey[100],
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    return Image.network(
                      snapshot.data!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
              // 이미지 위에 '저장' 버튼이나 '평점' 칩 올리기
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 14),
                      SizedBox(width: 4),
                      Text("4.5", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // 2. 텍스트 정보 영역
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // 카페 특징 태그 (예시)
                Row(
                  children: [
                    _buildTag("디저트 맛집"),
                    const SizedBox(width: 4),
                    _buildTag("조용한"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

  // 태그 생성을 위한 보조 위젯
  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.lightBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Colors.lightBlue, fontWeight: FontWeight.w600),
      ),
    );
  }
}