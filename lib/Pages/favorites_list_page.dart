import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/providers/favorites_provider.dart';
import 'package:placelist/Pages/store_detail_page.dart';
import 'package:placelist/DB/store.dart';

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
                  ref
                      .read(favoritesProvider.notifier)
                      .toggleFavorite(store.id!)
                      .catchError((e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('찜 처리 중 오류가 발생했습니다. 다시 시도해 주세요.'),
                      ),
                    );
                  });
                  // favoritedStoresProvider는 favoritesProvider를 watch하므로
                  // toggleFavorite 후 state가 변경되면 자동으로 재계산됩니다.
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
    if (store.imageUrls.isNotEmpty) {
      return Image.network(
        store.imageUrls.first,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, e, s) =>
            Container(width: 80, height: 80, color: Colors.grey[200]),
      );
    }
    return Container(width: 80, height: 80, color: Colors.grey[200]);
  }
}
