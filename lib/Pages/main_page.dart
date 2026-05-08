import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/store_database.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:placelist/Pages/store_detail_page.dart';
import 'package:placelist/widgets/category_section.dart';
import 'package:placelist/providers/favorites_provider.dart';
import 'package:placelist/providers/navigation_provider.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final StoreDatabase storesDatabase = StoreDatabase();
  final SupabaseClient _client = Supabase.instance.client;
  int _reloadToken = 0;
  String _searchQuery = '';
  late Future<List<Store>> _storesFuture;

  @override
  void initState() {
    super.initState();
    _storesFuture = storesDatabase.getStores();
  }

  Future<String> _getMainImageUrl(Store store) async {
    if (store.imageUrl != null && store.imageUrl!.isNotEmpty) {
      return store.imageUrl!;
    }
    final storage = _client.storage.from(supabaseStorageBucket);
    if (store.imagePath != null && store.imagePath!.isNotEmpty) {
      return storage.getPublicUrl(store.imagePath!);
    }
    final path = '${store.folderName}/1.jpeg';
    return storage.getPublicUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 검색창
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  textAlignVertical: TextAlignVertical.center,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 32,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    hintText: "카페 이름을 검색해보세요",
                    hintStyle: GoogleFonts.notoSans(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            // Category Filter Section
            const CategoryFilterSection(),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Expanded(
              child: FutureBuilder<List<Store>>(
                key: ValueKey(_reloadToken),
                future: _storesFuture,
                builder: (context, snapshot) {
                  List<Store> stores = snapshot.data ?? [];
                  
                  if (_searchQuery.isNotEmpty) {
                    stores = stores.where((store) =>
                        store.name.toLowerCase().contains(_searchQuery.toLowerCase())
                    ).toList();
                  }

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      stores.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (stores.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildCafeList(stores);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 당근마켓 스타일의 리스트 뷰
  Widget _buildCafeList(List<Store> stores) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: stores.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: Color(0xFFEEEEEE),
      ),
      itemBuilder: (context, index) {
        final store = stores[index];
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => StoreDetailPage(store: store)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 왼쪽 이미지
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 130,
                    height: 130,
                    child: FutureBuilder<String>(
                      future: _getMainImageUrl(store),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Container(color: Colors.grey[100]);
                        }
                        return Image.network(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: Colors.grey[100]),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 오른쪽 정보
                Expanded(
                  child: SizedBox(
                    height: 130,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name,
                          style: GoogleFonts.notoSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // 평점 위치를 카페명 밑으로 이동
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 2),
                            Text(
                              (store.rating ?? 0.0).toStringAsFixed(1),
                              style: GoogleFonts.notoSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "•  서울시 어딘가",
                              style: GoogleFonts.notoSans(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                            Consumer(
                              builder: (context, ref, child) {
                                final favoriteIds = ref.watch(favoritesProvider);
                                final isFavorited = store.id != null && favoriteIds.contains(store.id);

                                return Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        final user = Supabase.instance.client.auth.currentUser;
                                        if (user == null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('찜 기능을 사용하려면 로그인이 필요합니다.')),
                                          );
                                          ref.read(navigationProvider.notifier).setIndex(2);
                                          return;
                                        }
                                        if (store.id != null) {
                                          ref.read(favoritesProvider.notifier).toggleFavorite(store.id!);
                                        }
                                      },
                                      icon: Icon(
                                        isFavorited ? Icons.favorite : Icons.favorite_border,
                                        color: isFavorited ? Colors.redAccent : Colors.grey[400],
                                        size: 20,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            "아직 등록된 카페가 없네요!",
            style: GoogleFonts.notoSans(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
