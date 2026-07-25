import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/Pages/store_detail_page.dart';
import 'package:placelist/data/category_data.dart';
import 'package:placelist/providers/category_provider.dart';
import 'package:placelist/providers/favorites_provider.dart';
import 'package:placelist/providers/navigation_provider.dart';
import 'package:placelist/providers/search_history_provider.dart';
import 'package:placelist/providers/stores_provider.dart';
import 'package:placelist/widgets/category_section.dart';
import 'package:placelist/widgets/map_marker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late final TextEditingController _searchController;
  bool _isMapView = false;
  String _sortBy = 'default'; // 'default', 'rating', 'name'
  Store? _selectedMapStore;

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

  void _onSearchSubmitted(String value) {
    final query = value.trim();
    if (query.isNotEmpty) {
      ref.read(searchQueryProvider.notifier).state = query;
      ref.read(searchHistoryProvider.notifier).addQuery(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategories = ref.watch(selectedCategoriesProvider);
    final storesAsync = ref.watch(storesProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final searchHistory = ref.watch(searchHistoryProvider);
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
            // 검색바 및 뷰 토글
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
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
                        onSubmitted: _onSearchSubmitted,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                            size: 20,
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 32),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(searchQueryProvider.notifier).state = '';
                                  },
                                )
                              : null,
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
                  const SizedBox(width: 8),
                  // 리스트/지도 토글 버튼
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isMapView ? Icons.format_list_bulleted : Icons.map_outlined,
                        color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF3267A2),
                      ),
                      tooltip: _isMapView ? '목록으로 보기' : '지도로 보기',
                      onPressed: () {
                        setState(() {
                          _isMapView = !_isMapView;
                          _selectedMapStore = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 최근 검색어 Chip 목록 (검색어가 비어있거나 히스토리가 있을 때)
            if (searchHistory.isNotEmpty)
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: searchHistory.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final item = searchHistory[index];
                    return InputChip(
                      label: Text(item, style: const TextStyle(fontSize: 12)),
                      backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () {
                        ref.read(searchHistoryProvider.notifier).removeQuery(item);
                      },
                      onPressed: () {
                        _searchController.text = item;
                        ref.read(searchQueryProvider.notifier).state = item;
                        _onSearchSubmitted(item);
                      },
                    );
                  },
                ),
              ),

            const SizedBox(height: 4),
            const CategoryFilterSection(),
            const SizedBox(height: 8),

            // 정렬 옵션 Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isMapView ? '지도 탐색' : '카페 목록',
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  PopupMenuButton<String>(
                    initialValue: _sortBy,
                    onSelected: (val) {
                      setState(() {
                        _sortBy = val;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.sort,
                            size: 16,
                            color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF3267A2),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _sortBy == 'rating'
                                ? '평점 높은 순'
                                : _sortBy == 'name'
                                    ? '이름순'
                                    : '추천순',
                            style: GoogleFonts.notoSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF3267A2),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 18),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'default', child: Text('추천순')),
                      const PopupMenuItem(value: 'rating', child: Text('평점 높은 순')),
                      const PopupMenuItem(value: 'name', child: Text('이름순')),
                    ],
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEEEEEE)),

            // 메인 컨텐츠 (리스트 뷰 vs 지도 뷰)
            Expanded(
              child: storesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) =>
                    Center(child: Text("오류가 발생했습니다: $err", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),
                data: (storesList) {
                  var stores = List<Store>.from(storesList);

                  if (searchQuery.isNotEmpty) {
                    final terms = searchQuery
                        .split(RegExp(r'\s+'))
                        .map((t) => t.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();

                    if (terms.isNotEmpty) {
                      stores = stores.where((store) {
                        return terms.every((term) {
                          if (term.startsWith('#')) {
                            final q = term.substring(1).toLowerCase();
                            if (q.isEmpty) return true;
                            final tagMatch = store.categoryTags.any(
                              (tag) => tag.toLowerCase().contains(q),
                            );
                            final catMatch = getStoreCategories(store).any(
                              (cat) => cat.label.toLowerCase().contains(q),
                            );
                            final regionMatch =
                                store.region?.toLowerCase().contains(q) ?? false;
                            return tagMatch || catMatch || regionMatch;
                          } else {
                            final q = term.toLowerCase();
                            final nameMatch = store.name.toLowerCase().contains(q);
                            final regionMatch =
                                store.region?.toLowerCase().contains(q) ?? false;
                            final tagMatch = store.categoryTags.any(
                              (tag) => tag.toLowerCase().contains(q),
                            );
                            final catMatch = getStoreCategories(store).any(
                              (cat) => cat.label.toLowerCase().contains(q),
                            );
                            return nameMatch || regionMatch || tagMatch || catMatch;
                          }
                        });
                      }).toList();
                    }
                  }

                  if (selectedCategories.isNotEmpty) {
                    stores = stores.where((store) {
                      final storeCats = getStoreCategories(store);
                      return ref
                          .read(selectedCategoriesProvider.notifier)
                          .matchesAll(storeCats);
                    }).toList();
                  }

                  // 정렬 적용
                  if (_sortBy == 'rating') {
                    stores.sort((a, b) => (b.rating ?? 0.0).compareTo(a.rating ?? 0.0));
                  } else if (_sortBy == 'name') {
                    stores.sort((a, b) => a.name.compareTo(b.name));
                  }

                  if (stores.isEmpty) {
                    final hasFilter = searchQuery.isNotEmpty || selectedCategories.isNotEmpty;
                    return _buildEmptyState(isDark, isFiltered: hasFilter);
                  }

                  if (_isMapView) {
                    return _buildMapView(stores, isDark);
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

  Widget _buildMapView(List<Store> stores, bool isDark) {
    if (kIsWeb) {
      return Center(
        child: Text(
          '웹 환경에서는 기본 지도 호환 모드로 작동합니다.',
          style: GoogleFonts.notoSans(color: isDark ? Colors.white70 : Colors.black87),
        ),
      );
    }

    final validStores = stores.where((s) => s.latitude != null && s.longitude != null).toList();

    if (validStores.isEmpty) {
      return Center(
        child: Text(
          "지도에 표시할 위치 정보가 없습니다.",
          style: GoogleFonts.notoSans(color: isDark ? Colors.white54 : Colors.grey[600]),
        ),
      );
    }

    final initialLat = validStores.first.latitude!;
    final initialLng = validStores.first.longitude!;

    return Stack(
      children: [
        NaverMap(
          options: NaverMapViewOptions(
            initialCameraPosition: NCameraPosition(
              target: NLatLng(initialLat, initialLng),
              zoom: 13,
            ),
            locationButtonEnable: true,
            indoorEnable: true,
          ),
          onMapReady: (controller) async {
            final markers = <NMarker>{};
            for (final store in validStores) {
              if (store.latitude == null || store.longitude == null) continue;
              final isSelected = _selectedMapStore?.id == store.id;
              final marker = await buildCustomMarker(
                context: context,
                store: store,
                isSelected: isSelected,
                isDark: isDark,
              );
              marker.setOnTapListener((NMarker m) async {
                if (!mounted) return;
                setState(() {
                  _selectedMapStore = store;
                });
                // 탭한 마커 위치로 지도를 부드럽게 이동 및 줌인
                if (store.latitude != null && store.longitude != null) {
                  controller.updateCamera(
                    NCameraUpdate.scrollAndZoomTo(
                      target: NLatLng(store.latitude!, store.longitude!),
                      zoom: 15.5,
                    ),
                  );
                }
                // 선택 마커 강조 갱신
                controller.clearOverlays();
                for (final s in validStores) {
                  if (s.latitude == null || s.longitude == null) continue;
                  final updated = await buildCustomMarker(
                    context: context,
                    store: s,
                    isSelected: s.id == store.id,
                    isDark: isDark,
                  );
                  updated.setOnTapListener((NMarker m2) async {
                    if (!mounted) return;
                    setState(() => _selectedMapStore = s);
                    if (s.latitude != null && s.longitude != null) {
                      controller.updateCamera(
                        NCameraUpdate.scrollAndZoomTo(
                          target: NLatLng(s.latitude!, s.longitude!),
                          zoom: 15.5,
                        ),
                      );
                    }
                  });
                  controller.addOverlayAll({updated});
                }
              });
              markers.add(marker);
            }
            if (markers.isNotEmpty) {
              controller.addOverlayAll(markers);
            }
          },
        ),
        if (_selectedMapStore != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 100,
            child: _buildStorePreviewCard(_selectedMapStore!, isDark),
          ),
      ],
    );
  }

  Widget _buildStorePreviewCard(Store store, bool isDark) {
    final imageUrl = _getMainImageUrl(store);
    return Card(
      elevation: 8,
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 70,
                    height: 70,
                    color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 70,
                    height: 70,
                    color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                    child: Icon(
                      Icons.broken_image,
                      color: isDark ? Colors.white24 : Colors.grey[400],
                      size: 24,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    store.name,
                    style: GoogleFonts.notoSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        (store.rating ?? 0.0).toStringAsFixed(1),
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          store.region ?? '',
                          style: GoogleFonts.notoSans(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StoreDetailPage(store: store),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3267A2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('상세보기'),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                setState(() {
                  _selectedMapStore = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCafeList(List<Store> stores, bool isDark) {
    return RefreshIndicator(
      onRefresh: () => ref.read(storesProvider.notifier).fetchStores(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[100],
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          },
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
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, {bool isFiltered = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltered ? Icons.search_off_outlined : Icons.storefront_outlined,
              size: 80,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? "검색 결과가 없습니다" : "아직 등록된 카페가 없네요!",
              style: GoogleFonts.notoSans(
                color: isDark ? Colors.white70 : Colors.grey[800],
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 8),
              Text(
                "다른 검색어나 카테고리 필터를 시도해보세요.",
                style: GoogleFonts.notoSans(
                  color: isDark ? Colors.white38 : Colors.grey[600],
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
