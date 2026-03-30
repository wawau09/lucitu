import 'package:flutter/material.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/DB/store_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:placelist/supabase_config.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => Search();
}

class Search extends State<SearchPage> {
  final storesDatabase = StoreDatabase();
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> getImageUrl(String folderName, String fileName) async {
    try {
      final path = '$folderName/$fileName.jpeg';
      return _client.storage.from(supabaseStorageBucket).getPublicUrl(path);
    } catch (e) {
      return ''; 
    }
  }

  // 이제 int index나 id가 아닌, 완성된 Store 객체를 통째로 받습니다.
  Widget buildCard(Store store) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      showImagePopup(store.id ?? '알 수 없음');
    },
    child: Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 이미지 영역
          Expanded( 
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              // Supabase Storage에서 URL 가져오기
              child: FutureBuilder<String>(
                future: getImageUrl(store.folderName, "1"), 
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Icon(Icons.broken_image, size: 50, color: Colors.grey);
                  }
                  return Image.network(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                  );
                },
              ),
            ),
          ),
          // 2. 텍스트 영역 (DB를 다시 호출하지 않고 Store 객체의 속성을 바로 사용!)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              store.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ),
  );

  void showImagePopup(String storeId) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("문서 ID: $storeId 번 가게입니다."),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("닫기"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<List<Store>>(
        stream: storesDatabase.stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stores = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              itemCount: stores.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 250, 
                childAspectRatio: 0.8,   
                crossAxisSpacing: 16,    
                mainAxisSpacing: 16,     
              ),
              itemBuilder: (context, index) {
                // Store 객체를 통째로 buildCard에 넘겨줍니다.
                return buildCard(stores[index]); 
              },
            ),
          );
        },
      ),
    );
  }
}