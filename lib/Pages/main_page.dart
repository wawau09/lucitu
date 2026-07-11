import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/Pages/store_detail_page.dart';
import 'package:placelist/data/category_data.dart';
import 'package:placelist/providers/category_provider.dart';
import 'package:placelist/providers/favorites_provider.dart';
import 'package:placelist/providers/navigation_provider.dart';
import 'package:placelist/providers/stores_provider.dart';
import 'package:placelist/widgets/category_section.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _getMainImageUrl(Store store) {
    return store.imageUrls.isNotEmpty ? store.imageUrls.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategories = ref.watch(selectedCategoriesProvider);
    final storesAsync = ref.watch(storesProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<String>(searchQueryProvider, (previous, next) {
      if (_searchController.text != next) {
        _searchController.text = next;
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _searchController,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  onChanged: (value) {
                    ref.read(searchQueryProvider.notifier).state = value;
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.grey,
                      size: 20,
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 32),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    hintText: "카페 이름 검색 또는 #카테고리",
                    hintStyle: GoogleFonts.notoSans(
                      color: isDark ? Colors.white38 : Colors.grey,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const CategoryFilterSection(),
            const SizedBox(height: 12),
            Divider(height: 1, color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEEEEEE)),
            Expanded(
              child: storesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) =>
                    Center(child: Text("오류가 발생했습니다: $err", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),
                data: (storesList) {
                  var stores = List<Store>.from(storesList);

                  if (searchQuery.isNotEmpty) {
                    if (searchQuery.startsWith('#')) {
                      // # 접두사: 카테고리 태그 또는 지역 필터링
                      final q = searchQuery.substring(1).toLowerCase().trim();
                      if (q.isNotEmpty) {
                        stores = stores.where((store) {
                          // region 매칭
                          final regionMatch = store.region != null &&
                              store.region!.toLowerCase().contains(q);
                          // categoryTags 직접 매칭
                          final tagMatch = store.categoryTags.any(
                            (tag) => tag.toLowerCase().contains(q),
                          );
                          // allCategories label 매칭 후 store의 category와 비교
                          final catMatch = getStoreCategories(store).any(
                            (cat) => cat.label.toLowerCase().contains(q),
                          );
                          return regionMatch || tagMatch || catMatch;
                        }).toList();
                      }
                    } else {
                      // 일반 검색: 카페 이름 + 카테고리 태그 + 지역
                      final q = searchQuery.toLowerCase();
                      stores = stores
                          .where(
                            (store) =>
                                store.name.toLowerCase().contains(q) ||
                                (store.region != null &&
                                    store.region!.toLowerCase().contains(q)) ||
                                store.categoryTags.any(
                                  (tag) => tag.toLowerCase().contains(q),
                                ),
                          )
                          .toList();
                    }
                  }

                  if (selectedCategories.isNotEmpty) {
                    stores = stores.where((store) {
                      final storeCats = getStoreCategories(store);
                      return ref
                          .read(selectedCategoriesProvider.notifier)
                          .matchesAny(storeCats);
                    }).toList();
                  }

                  if (stores.isEmpty) {
                    return _buildEmptyState(isDark);
                  }

                  return _buildCafeList(stores, isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCafeList(List<Store> stores, bool isDark) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: stores.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEEEEEE),
      ),
      itemBuilder: (context, index) {
        final store = stores[index];
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StoreDetailPage(store: store),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 130,
                    height: 130,
                    child: Builder(builder: (context) {
                      final imageUrl = _getMainImageUrl(store);
                      if (imageUrl == null) {
                        return Container(color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[100]);
                      }
                      return Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[100]),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 16),
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
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              (store.rating ?? 0.0).toStringAsFixed(1),
                              style: GoogleFonts.notoSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                [
                                  if (store.region != null &&
                                      store.region!.isNotEmpty)
                                    store.region!,
                                  ...store.categoryTags.take(2),
                                ].join(' · '),
                                style: GoogleFonts.notoSans(
                                  fontSize: 13,
                                  color: isDark ? Colors.white30 : Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Consumer(
                          builder: (context, ref, child) {
                            final favoriteIds = ref.watch(favoritesProvider);
                            final isFavorited = store.id != null &&
                                favoriteIds.contains(store.id);

                            return Align(
                              alignment: Alignment.bottomRight,
                              child: IconButton(
                                onPressed: () {
                                  final user =
                                      Supabase.instance.client.auth.currentUser;
                                  if (user == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '찜 기능을 사용하려면 로그인이 필요합니다.',
                                        ),
                                      ),
                                    );
                                    ref
                                        .read(navigationProvider.notifier)
                                        .setIndex(2);
                                    return;
                                  }
                                  if (store.id != null) {
                                    ref
                                        .read(favoritesProvider.notifier)
                                        .toggleFavorite(store.id!)
                                        .catchError((e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              '찜 처리 중 오류가 발생했습니다. 다시 시도해 주세요.'),
                                        ),
                                      );
                                    });
                                  }
                                },
                                icon: Icon(
                                  isFavorited
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFavorited
                                      ? Colors.redAccent
                                      : (isDark ? Colors.white30 : Colors.grey[400]),
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            );
                          },
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined, size: 80, color: isDark ? Colors.white10 : Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            "아직 등록된 카페가 없네요!",
            style: GoogleFonts.notoSans(color: isDark ? Colors.white30 : Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
