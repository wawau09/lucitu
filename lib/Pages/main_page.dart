import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/store_database.dart';
import 'package:placelist/DB/store.dart'; 
import 'package:placelist/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final StoreDatabase storesDatabase = StoreDatabase();
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> _getMainImageUrl(Store store) async {
    final storage = _client.storage.from(supabaseStorageBucket);
    final path = '${store.folderName}/1.jpeg';
    try {
      return await storage.createSignedUrl(path, 60 * 60);
    } catch (_) {
      try {
        return storage.getPublicUrl(path);
      } catch (_) {
        return '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // 세련된 연회색 배경
      body: StreamBuilder<List<Store>>(
        stream: storesDatabase.stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('데이터 로드 중 오류가 발생했습니다.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<Store> stores = snapshot.data ?? [];

          if (stores.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("카페"),
              Expanded(child: _buildCafeCards(stores)),
            ],
          );
        },
      ),
      // 카페 추가 플로팅 버튼
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: 카페 추가 페이지 연결
        },
        label: const Text("장소 추가", style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
    );
  }

  // 섹션 제목 위젯
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: GoogleFonts.notoSans(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  // 카페 카드 리스트 (기존 인기 카드 스타일 재사용)
  Widget _buildCafeCards(List<Store> stores) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: stores.length,
      itemBuilder: (context, index) {
        final store = stores[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          color: Colors.white,
          elevation: 3,
          shadowColor: Colors.black.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              // 카드 상단 이미지
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  width: double.infinity,
                  height: 230,
                  child: FutureBuilder<String>(
                    future: _getMainImageUrl(store),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, color: Colors.white, size: 40),
                        );
                      }
                      return Image.network(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, color: Colors.grey, size: 24),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                    store.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 데이터가 없을 때 표시할 화면
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 100, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            "아직 등록된 장소가 없네요!",
            style: GoogleFonts.notoSans(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}