import 'package:flutter/material.dart';
import 'package:placelist/DB/store_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => Search();
}

class Search extends State<SearchPage> {
  final storesDatabase = StoreDatabase();
  final supabase = Supabase.instance.client;

  // ... (기존 getID, getFolder 함수들은 그대로 둠) ...
  Future<String> getID(int id) async {
    final response = await supabase.from('stores').select('name').eq('id', id).maybeSingle();
    return response?['name']?.toString() ?? "NULL";
  }

  String getFolderImage(String folder, String name) {
    final publicUrl = supabase.storage.from('image').getPublicUrl('$folder/$name.jpeg');
    return publicUrl;
  }

  Future<String> getFolder(int id) async {
    final response = await supabase.from('stores').select('folder_name').eq('id', id).maybeSingle(); // stores -> places 확인 필요
    return response?['folder_name']?.toString() ?? "0";
  }

  // index 대신 진짜 ID를 받도록 수정
  Widget buildCard(int storeId) => Card( // Card 위젯으로 감싸면 그림자 효과 등 예쁨
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, // 가로로 꽉 차게
      children: [
        // 1. 이미지 영역 (비율 유지)
        Expanded( 
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: FutureBuilder<String>(
              future: getFolder(storeId), // 리스트 순서(index)가 아니라 진짜 ID를 넣어야 함
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  return Image.network(
                    getFolderImage(snapshot.data ?? 'test', "1"),
                    fit: BoxFit.cover, // 박스 크기에 맞춰 꽉 채우기
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error), // 에러 처리
                  );
                }
              },
            ),
          ),
        ),
        // 2. 텍스트 영역
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: FutureBuilder<String>(
            future: getID(storeId),
            builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(height: 20, child: LinearProgressIndicator());
              } else {
                return Text(
                  snapshot.data ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                );
              }
            },
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder(
        stream: storesDatabase.stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stores = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0), // 전체 여백 추가
            child: GridView.builder(
              itemCount: stores.length,
              // ✅ 여기가 핵심! 반응형 그리드 설정
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 250, // 카드의 최대 너비 (이것보다 넓어지면 칸 수가 늘어남)
                childAspectRatio: 0.8,   // 가로 세로 비율 (0.8 = 세로가 약간 더 김)
                crossAxisSpacing: 16,    // 좌우 간격
                mainAxisSpacing: 16,     // 위아래 간격
              ),
              itemBuilder: (context, index) {
                // stores 리스트 안에 있는 객체에서 실제 id를 뽑아야 정확합니다.
                // 예: stores[index]['id'] 또는 stores[index].id (모델에 따라 다름)
                // 여기서는 일단 item의 id를 가져온다고 가정합니다.
                final int storeId = int.tryParse(stores[index].id.toString()) ?? 0;
                
                return buildCard(storeId);
              },
            ),
          );
        },
      ),
    );
  }
} 