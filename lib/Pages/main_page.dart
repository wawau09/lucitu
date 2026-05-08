import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/store_database.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:placelist/Pages/store_detail_page.dart';
import 'package:placelist/widgets/category_section.dart';

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
    // 1. 우선 imageUrl이 있으면 그대로 사용
    if (store.imageUrl != null && store.imageUrl!.isNotEmpty) {
      return store.imageUrl!;
    }

    final storage = _client.storage.from(supabaseStorageBucket);

    // 2. imagePath가 있으면 Storage에서 가져옴
    if (store.imagePath != null && store.imagePath!.isNotEmpty) {
      return storage.getPublicUrl(store.imagePath!);
    }

    // 3. 폴더명 기반 기본 경로 시도 (1.jpeg가 기본이라고 가정)
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

            // 검색창 (항상 표시)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      padding: const EdgeInsets.only(left: 14, right: 16),
                      child: TextField(
                        textAlignVertical: TextAlignVertical.center,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontSize: 14,
                          height: 1.2,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, color: Colors.black, size: 20),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 40,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          hintText: "Search cafes",
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontSize: 14,
                            height: 1.2,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      // Navigate to account page logic can be added here
                    },
                    icon: const Icon(
                      Icons.account_circle,
                      size: 32,
                      color: Colors.black87,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Category Filter Section
            const CategoryFilterSection(),
            const SizedBox(height: 12),
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

                  if (snapshot.hasError) {
                    debugPrint('Stream error: ${snapshot.error}');
                    if (stores.isEmpty) {
                      return _buildErrorState();
                    }
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      stores.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (stores.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildCafeCards(stores);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 카페 카드 리스트
  Widget _buildCafeCards(List<Store> stores) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.67,
      ),
      itemCount: stores.length,
      itemBuilder: (context, index) {
        final store = stores[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder:
                    (context, animation, secondaryAnimation) =>
                        StoreDetailPage(store: store),
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) {
                  return SlideTransition(
                    position: animation.drive(
                      Tween(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeOutCubic)),
                    ),
                    child: child,
                  );
                },
              ),
            );
          },
          child: Card(
            margin: EdgeInsets.zero,
            color: Colors.white,
            elevation: 3,
            shadowColor: Colors.black.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: FutureBuilder<String>(
                          future: _getMainImageUrl(store),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              );
                            }
                            return Image.network(
                              snapshot.data!,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) => Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                      size: 24,
                                    ),
                                  ),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              (store.rating ?? 0.0).toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            store.name,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.favorite_border,
                            color: Colors.grey,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
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


  // 데이터가 없을 때 표시할 화면
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined, size: 100, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            "아직 등록된 장소가 없네요!",
            style: GoogleFonts.notoSans(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('데이터 로드 중 오류가 발생했습니다.', style: TextStyle(fontSize: 15)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _storesFuture = storesDatabase.getStores();
                _reloadToken++;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('다시 불러오기'),
          ),
        ],
      ),
    );
  }
}
