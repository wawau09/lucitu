import 'dart:async';
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
import 'package:placelist/providers/stores_provider.dart';
import 'package:placelist/widgets/category_section.dart';
import 'package:placelist/widgets/map_marker.dart';
import 'package:placelist/utils/map_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:placelist/widgets/shimmer_loading.dart';
import 'package:placelist/widgets/error_retry_widget.dart';
import 'package:placelist/utils/app_colors.dart';
import 'package:placelist/Pages/map_stub.dart'
    if (dart.library.html) 'package:placelist/Pages/map_web.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late final TextEditingController _searchController;
  Timer? _debounceTimer;
  bool _isMapView = false;
  String _sortBy = 'default'; // 'default', 'rating', 'name'
  Store? _selectedMapStore;
  NaverMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String? _getMainImageUrl(Store store) {
    return store.imageUrls.isNotEmpty ? store.imageUrls.first : null;
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(searchQueryProvider.notifier).state = value;
      }
    });
  }

  void _onSearchSubmitted(String value) {
    _debounceTimer?.cancel();
    final query = value.trim();
    ref.read(searchQueryProvider.notifier).state = query;
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
                        onChanged: _onSearchChanged,
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
                                    _debounceTimer?.cancel();
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
                        color: isDark ? AppColors.accentLight : AppColors.primary,
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
                            color: isDark ? AppColors.accentLight : AppColors.primary,
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
                              color: isDark ? AppColors.accentLight : AppColors.primary,
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
                loading: () => ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: 5,
                  itemBuilder: (context, index) => const StoreSkeletonCard(),
                ),
                error: (err, stack) => ErrorRetryWidget(
                  message: err.toString(),
                  onRetry: () => ref.read(storesProvider.notifier).fetchStores(),
                ),
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

  Future<void> _renderMapMarkers(
    NaverMapController controller,
    List<MapStoreItem> mapStoreItems,
    bool isDark,
  ) async {
    final markers = <NMarker>{};
    for (final item in mapStoreItems) {
      final isSelected = _selectedMapStore?.id == item.store.id;
      final marker = await buildCustomMarker(
        context: context,
        store: item.store,
        isSelected: isSelected,
        isDark: isDark,
        overrideLat: item.displayLat,
        overrideLng: item.displayLng,
        clusterIndex: item.clusterIndex,
        clusterTotal: item.clusterTotal,
      );
      marker.setOnTapListener((NMarker m) async {
        if (!mounted) return;
        setState(() {
          _selectedMapStore = item.store;
        });
        controller.updateCamera(
          NCameraUpdate.scrollAndZoomTo(
            target: NLatLng(item.displayLat, item.displayLng),
            zoom: 15.5,
          ),
        );
        await _renderMapMarkers(controller, mapStoreItems, isDark);
      });
      markers.add(marker);
    }
    controller.clearOverlays();
    if (markers.isNotEmpty) {
      controller.addOverlayAll(markers);
    }
  }

  Widget _buildMapView(List<Store> stores, bool isDark) {
    final mapStoreItems = groupStoresByLocation(stores);

    final initialLat = mapStoreItems.isNotEmpty ? mapStoreItems.first.displayLat : 35.155;
    final initialLng = mapStoreItems.isNotEmpty ? mapStoreItems.first.displayLng : 129.06;

    final Widget mapWidget = kIsWeb
        ? Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[100],
            ),
            child: getWebMapStores(
              stores,
              selectedStoreId: _selectedMapStore?.id,
              onStoreSelected: (storeId) {
                final match = stores.firstWhere(
                  (s) => s.id == storeId,
                  orElse: () => stores.first,
                );
                setState(() {
                  _selectedMapStore = match;
                });
              },
            ),
          )
        : (mapStoreItems.isEmpty
            ? Center(
                child: Text(
                  "지도에 표시할 위치 정보가 없습니다.",
                  style: GoogleFonts.notoSans(
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              )
            : NaverMap(
                options: NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: NLatLng(initialLat, initialLng),
                    zoom: 13,
                  ),
                  locationButtonEnable: true,
                  indoorEnable: true,
                ),
                onMapReady: (controller) async {
                  _mapController = controller;
                  await _renderMapMarkers(controller, mapStoreItems, isDark);
                },
              ));

    return Stack(
      children: [
        // 1. 전체 화면 배경 지도
        Positioned.fill(child: mapWidget),

        // 2. 모바일 친화적 DraggableScrollableSheet (1단계: 요약 카드, 2단계: 전체 목록)
        _buildMapDraggableSheet(stores, mapStoreItems, isDark),
      ],
    );
  }

  Widget _buildMapDraggableSheet(
    List<Store> stores,
    List<MapStoreItem> mapStoreItems,
    bool isDark,
  ) {
    final activeStore = _selectedMapStore ?? (stores.isNotEmpty ? stores.first : null);

    return DraggableScrollableSheet(
      initialChildSize: 0.28,
      minChildSize: 0.12,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.12, 0.28, 0.88],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 1,
              ),
            ),
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 드래그 핸들 (Pill Handle)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // 헤더 바 (주변 카페 수 & 전체보기)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.coffee_rounded,
                                size: 18,
                                color: isDark ? AppColors.accentLight : AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _selectedMapStore != null ? '선택된 카페' : '주변 카페',
                                style: GoogleFonts.notoSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF2C2C2E)
                                      : AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${stores.length}곳',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white70 : AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_selectedMapStore != null)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedMapStore = null;
                                });
                                if (kIsWeb) {
                                  selectWebMapMarker('');
                                } else if (_mapController != null) {
                                  _renderMapMarkers(_mapController!, mapStoreItems, isDark);
                                }
                              },
                              child: Text(
                                '전체 보기',
                                style: GoogleFonts.notoSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.accentLight : AppColors.primary,
                                ),
                              ),
                            )
                          else
                            Text(
                              '위로 당겨서 목록 보기 ↑',
                              style: GoogleFonts.notoSans(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // 1단계 요약 프리뷰 카드
                    if (activeStore != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                        child: _buildSheetActiveStoreCard(
                          activeStore,
                          mapStoreItems,
                          isDark,
                        ),
                      ),

                    Divider(
                      height: 1,
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '카페 목록 (${stores.length})',
                            style: GoogleFonts.notoSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white54 : Colors.grey[700],
                            ),
                          ),
                          Text(
                            '터치 시 지도로 이동',
                            style: GoogleFonts.notoSans(
                              fontSize: 11,
                              color: isDark ? Colors.white30 : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2단계 스크롤 시 전체 카페 목록
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final store = stores[index];
                    final isSelected = _selectedMapStore?.id == store.id;
                    return _buildSheetStoreListItem(
                      store,
                      isSelected,
                      mapStoreItems,
                      isDark,
                    );
                  },
                  childCount: stores.length,
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 90),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetActiveStoreCard(
    Store store,
    List<MapStoreItem> mapStoreItems,
    bool isDark,
  ) {
    final imageUrl = _getMainImageUrl(store);
    MapStoreItem? currentItem;
    for (final item in mapStoreItems) {
      if (item.store.id == store.id) {
        currentItem = item;
        break;
      }
    }
    final isCluster = currentItem != null && currentItem.clusterTotal > 1;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242426) : const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isCluster) ...[
            Builder(
              builder: (context) {
                final clusterStores = currentItem!.clusterStores;
                final totalCount = currentItem.clusterTotal;
                final currentIndex = clusterStores.indexWhere((s) => s.id == store.id);
                final validIndex = currentIndex >= 0 ? currentIndex : 0;

                void selectClusterStore(int newIndex) {
                  final targetStore = clusterStores[newIndex];
                  final targetItem = mapStoreItems.firstWhere(
                    (it) => it.store.id == targetStore.id,
                    orElse: () => currentItem!,
                  );
                  setState(() {
                    _selectedMapStore = targetStore;
                  });
                  if (kIsWeb) {
                    selectWebMapMarker(targetStore.id ?? '');
                  } else if (_mapController != null) {
                    _mapController!.updateCamera(
                      NCameraUpdate.scrollAndZoomTo(
                        target: NLatLng(targetItem.displayLat, targetItem.displayLng),
                        zoom: 15.5,
                      ),
                    );
                    _renderMapMarkers(_mapController!, mapStoreItems, isDark);
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '같은 위치 장소 (${validIndex + 1} / $totalCount)',
                        style: GoogleFonts.notoSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              final prevIdx = (validIndex - 1 + totalCount) % totalCount;
                              selectClusterStore(prevIdx);
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.chevron_left, size: 18),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              final nextIdx = (validIndex + 1) % totalCount;
                              selectClusterStore(nextIdx);
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.chevron_right, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StoreDetailPage(store: store),
                ),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[200],
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[200],
                              child: const Icon(Icons.coffee, size: 22, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[200],
                            child: const Icon(Icons.coffee, size: 22, color: Colors.grey),
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
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 2),
                          Text(
                            (store.rating ?? 0.0).toStringAsFixed(1),
                            style: GoogleFonts.notoSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              [
                                if (store.region != null && store.region!.isNotEmpty) store.region!,
                                ...store.categoryTags.take(1),
                              ].join(' · '),
                              style: GoogleFonts.notoSans(
                                fontSize: 11,
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
                const SizedBox(width: 8),
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
                    backgroundColor: isDark ? AppColors.accentLight : AppColors.primary,
                    foregroundColor: isDark ? AppColors.backgroundDark : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('상세보기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetStoreListItem(
    Store store,
    bool isSelected,
    List<MapStoreItem> mapStoreItems,
    bool isDark,
  ) {
    final imageUrl = _getMainImageUrl(store);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMapStore = store;
        });
        if (kIsWeb) {
          selectWebMapMarker(store.id ?? '');
        } else if (_mapController != null) {
          final targetItem = mapStoreItems.firstWhere(
            (it) => it.store.id == store.id,
            orElse: () => mapStoreItems.first,
          );
          _mapController!.updateCamera(
            NCameraUpdate.scrollAndZoomTo(
              target: NLatLng(targetItem.displayLat, targetItem.displayLng),
              zoom: 15.5,
            ),
          );
          _renderMapMarkers(_mapController!, mapStoreItems, isDark);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.primaryContainer.withValues(alpha: 0.4))
              : Colors.transparent,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 52,
                height: 52,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[200],
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[200],
                          child: const Icon(Icons.coffee, size: 18, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[200],
                        child: const Icon(Icons.coffee, size: 18, color: Colors.grey),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        (store.rating ?? 0.0).toStringAsFixed(1),
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [
                            if (store.region != null && store.region!.isNotEmpty) store.region!,
                            ...store.categoryTags.take(2),
                          ].join(' · '),
                          style: GoogleFonts.notoSans(
                            fontSize: 11,
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
            IconButton(
              icon: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark ? Colors.white30 : Colors.grey.shade400,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StoreDetailPage(store: store),
                  ),
                );
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
                        return CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[100],
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[100],
                            child: Icon(
                              Icons.broken_image,
                              color: isDark ? Colors.white24 : Colors.grey[400],
                              size: 24,
                            ),
                          ),
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
