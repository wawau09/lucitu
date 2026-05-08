import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/providers/favorites_provider.dart';
import 'package:placelist/Pages/store_detail_page.dart';
import 'package:placelist/DB/store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:placelist/supabase_config.dart';

class FavoritesListPage extends ConsumerWidget {
  const FavoritesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritedStoresProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "찜한 카페",
          style: GoogleFonts.notoSans(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: favoritesAsync.when(
        data: (stores) {
          if (stores.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "찜한 카페가 없습니다.",
                    style: GoogleFonts.notoSans(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: stores.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final store = stores[index];
              return _buildFavoriteCard(context, ref, store);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('오류 발생: $err')),
      ),
    );
  }

  Widget _buildFavoriteCard(BuildContext context, WidgetRef ref, Store store) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => StoreDetailPage(store: store)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildStoreImage(store),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    style: GoogleFonts.notoSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                   const SizedBox(height: 4),
                   if (store.location != null)
                     Text(
                       store.location!,
                       style: GoogleFonts.notoSans(
                         fontSize: 13,
                         color: Colors.grey[600],
                       ),
                     ),
                   const SizedBox(height: 4),
                   Row(
                     children: [
                       const Icon(Icons.star, color: Colors.amber, size: 16),
                       const SizedBox(width: 4),
                       Text(
                         (store.rating ?? 0.0).toStringAsFixed(1),
                         style: const TextStyle(fontSize: 14, color: Colors.grey),
                       ),
                     ],
                   ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                if (store.id != null) {
                  ref.read(favoritesProvider.notifier).toggleFavorite(store.id!);
                  // 목록 갱신을 위해 favoritesProvider가 변경되면 favoritedStoresProvider도 재호출되도록 설정됨
                  ref.invalidate(favoritedStoresProvider);
                }
              },
              icon: const Icon(Icons.favorite, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreImage(Store store) {
    // 간단한 이미지 로딩 로직 (main_page.dart와 유사하게 구현 가능)
    final String imageUrl = store.imageUrl ?? '';
    if (imageUrl.isNotEmpty) {
      return Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover);
    }
    
    // Storage 경로 시도
    final storage = Supabase.instance.client.storage.from(supabaseStorageBucket);
    final path = '${store.folderName}/1.jpeg';
    
    return FutureBuilder<String>(
      future: Future.value(storage.getPublicUrl(path)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container(width: 80, height: 80, color: Colors.grey[200]);
        return Image.network(
          snapshot.data!,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, e, s) => Container(width: 80, height: 80, color: Colors.grey[200]),
        );
      },
    );
  }
}
