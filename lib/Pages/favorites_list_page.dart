import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/providers/favorites_provider.dart';
import 'package:placelist/Pages/store_detail_page.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/widgets/app_network_image.dart';

class FavoritesListPage extends ConsumerWidget {
  const FavoritesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritedStoresProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "찜한 카페",
          style: GoogleFonts.notoSans(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
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
                  Icon(Icons.favorite_border, size: 80, color: isDark ? Colors.white10 : Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "찜한 카페가 없습니다.",
                    style: GoogleFonts.notoSans(color: isDark ? Colors.white30 : Colors.grey),
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
              return _buildFavoriteCard(context, ref, store, isDark);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('오류 발생: $err', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),
      ),
    );
  }

  Widget _buildFavoriteCard(BuildContext context, WidgetRef ref, Store store, bool isDark) {
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
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
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
              child: _buildStoreImage(store, isDark),
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
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        (store.rating ?? 0.0).toStringAsFixed(1),
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.grey),
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
                      .then((_) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('\'${store.name}\' 찜 해제되었습니다.'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        action: SnackBarAction(
                          label: '실행 취소',
                          onPressed: () {
                            ref
                                .read(favoritesProvider.notifier)
                                .toggleFavorite(store.id!);
                          },
                        ),
                      ),
                    );
                  }).catchError((e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('찜 처리 중 오류가 발생했습니다. 다시 시도해 주세요.'),
                      ),
                    );
                  });
                }
              },
              icon: const Icon(Icons.favorite, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreImage(Store store, bool isDark) {
    return AppNetworkImage(
      imageUrls: store.imageUrls,
      width: 80,
      height: 80,
      borderRadius: BorderRadius.circular(8),
      isDark: isDark,
    );
  }
}
