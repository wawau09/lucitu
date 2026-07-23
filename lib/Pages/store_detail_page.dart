import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/DB/plan.dart';
import 'package:placelist/Pages/map_stub.dart'
    if (dart.library.html) 'package:placelist/Pages/map_web.dart';
import 'package:placelist/providers/category_provider.dart';
import 'package:placelist/providers/favorites_provider.dart';
import 'package:placelist/providers/navigation_provider.dart';
import 'package:placelist/providers/stores_provider.dart';
import 'package:placelist/providers/plans_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoreDetailPage extends ConsumerStatefulWidget {
  final Store store;

  const StoreDetailPage({super.key, required this.store});

  @override
  ConsumerState<StoreDetailPage> createState() => _StoreDetailPageState();
}

class _StoreDetailPageState extends ConsumerState<StoreDetailPage> {
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final storesAsync = ref.watch(storesProvider);
    final store = storesAsync.maybeWhen(
      data: (list) => list.firstWhere(
        (s) => s.id == widget.store.id,
        orElse: () => widget.store,
      ),
      orElse: () => widget.store,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImageHeader(store, isDark),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleRow(context, isDark),
                  const SizedBox(height: 8),
                  _buildCompactRating(store, isDark),
                  const SizedBox(height: 16),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF64B5F6) : Colors.lightBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "\uC0C1\uC138 \uC18C\uAC1C",
                    style: GoogleFonts.notoSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "${store.name}\uC5D0 \uB300\uD55C \uC815\uBCF4\uAC00 \uC5C5\uB370\uC774\uD2B8\uB420 \uC608\uC815\uC785\uB2C8\uB2E4.",
                    style: GoogleFonts.notoSans(
                      fontSize: 15,
                      height: 1.6,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (store.categoryTags.isNotEmpty)
                    _buildCategoryChips(store.categoryTags, isDark),
                  const SizedBox(height: 32),
                  if (store.menuBoard != null && store.menuBoard!.isNotEmpty) ...[
                    _buildMenuBoardSection(store.menuBoard!, isDark),
                    const SizedBox(height: 32),
                  ],
                  _buildRatingSection(context, store, isDark),
                  const SizedBox(height: 32),
                  if (store.latitude != null && store.longitude != null) ...[
                    _buildMapSection(store, isDark),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageHeader(Store store, bool isDark) {
    final imageUrls = store.imageUrls;

    if (imageUrls.isEmpty) {
      return SizedBox(
        height: 400,
        width: double.infinity,
        child: Container(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[200],
          child: Center(
            child: Icon(Icons.image_outlined, color: isDark ? Colors.white24 : Colors.grey, size: 80),
          ),
        ),
      );
    }

    return SizedBox(
      height: 400,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.mouse,
                PointerDeviceKind.touch,
                PointerDeviceKind.trackpad,
              },
            ),
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              return Container(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[100],
                child: Image.network(
                  imageUrls[index],
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[200],
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        color: isDark ? Colors.white24 : Colors.grey,
                        size: 60,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (imageUrls.length > 1)
            Positioned(
              bottom: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  imageUrls.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.blue
                          : (isDark ? Colors.white24 : Colors.grey.shade400),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 16,
            child: Material(
              color: isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        extendBodyBehindAppBar: true,
                        appBar: AppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          iconTheme:
                              const IconThemeData(color: Colors.white),
                        ),
                        body: PanoramaViewer(
                          child: Image.asset(
                            'assets/relax_inn_seaview_suite_4k.jpg',
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.threed_rotation,
                        size: 20,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "파노라마",
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleRow(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            widget.store.name,
            style: GoogleFonts.notoSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.2,
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '내 일정에 추가',
              icon: Icon(
                Icons.edit_calendar,
                color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF3267A2),
                size: 26,
              ),
              onPressed: () => _showAddToPlanSheet(context, widget.store),
            ),
            Consumer(
              builder: (context, ref, child) {
                final favoriteIds = ref.watch(favoritesProvider);
                final isFavorited =
                    widget.store.id != null && favoriteIds.contains(widget.store.id);

                return IconButton(
                  onPressed: () {
                    final user = Supabase.instance.client.auth.currentUser;
                    if (user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('찜 기능을 사용하려면 로그인이 필요합니다.')),
                      );
                      ref.read(navigationProvider.notifier).setIndex(2);
                      Navigator.pop(context);
                      return;
                    }
                    if (widget.store.id != null) {
                      ref
                          .read(favoritesProvider.notifier)
                          .toggleFavorite(widget.store.id!)
                          .catchError((e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('찜 처리 중 오류가 발생했습니다. 다시 시도해 주세요.'),
                          ),
                        );
                      });
                    }
                  },
                  icon: Icon(
                    isFavorited ? Icons.favorite : Icons.favorite_border,
                    color: isFavorited ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black87),
                    size: 28,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  void _showAddToPlanSheet(BuildContext context, Store store) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정에 추가하려면 로그인이 필요합니다.')),
      );
      ref.read(navigationProvider.notifier).setIndex(2);
      Navigator.pop(context);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, child) {
            final plansAsync = ref.watch(plansProvider);
            final isDark = Theme.of(context).brightness == Brightness.dark;
            String selectedTime = '12:00';

            return StatefulBuilder(
              builder: (context, setState) {
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                             Icon(Icons.edit_calendar, color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF3267A2)),
                            const SizedBox(width: 8),
                            Text(
                              '내 일정에 추가',
                              style: GoogleFonts.notoSans(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '\'${store.name}\' 카페를 방문할 일정을 선택하세요.',
                          style: GoogleFonts.notoSans(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        plansAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Text('일정을 불러오는 중 오류가 발생했습니다: $err'),
                          data: (plans) {
                            if (plans.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '생성된 일정이 없습니다.',
                                      style: GoogleFonts.notoSans(
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(sheetContext);
                                        ref.read(navigationProvider.notifier).setIndex(0);
                                        Navigator.pop(context);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF3267A2),
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('일정 탭에서 일정 생성하기'),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 250),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: plans.length,
                                    separatorBuilder: (_, __) => Divider(
                                      height: 1,
                                      color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                                    ),
                                    itemBuilder: (context, idx) {
                                      final plan = plans[idx];
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          plan.name,
                                          style: GoogleFonts.notoSans(
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${plan.planDate.year}-${plan.planDate.month.toString().padLeft(2, '0')}-${plan.planDate.day.toString().padLeft(2, '0')}',
                                          style: GoogleFonts.notoSans(
                                            fontSize: 12,
                                            color: isDark ? Colors.white38 : Colors.grey[600],
                                          ),
                                        ),
                                        trailing: ElevatedButton.icon(
                                          icon: const Icon(Icons.add, size: 16),
                                          label: const Text('추가'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF3267A2),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () async {
                                            try {
                                              await ref.read(plansProvider.notifier).addPlanItem(
                                                    planId: plan.id,
                                                    draft: PlanDraft(
                                                      title: store.name,
                                                      startTime: selectedTime,
                                                    ),
                                                  );
                                              if (sheetContext.mounted) {
                                                Navigator.pop(sheetContext);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('\'${plan.name}\' 일정에 추가되었습니다.'),
                                                    action: SnackBarAction(
                                                      label: '일정 확인',
                                                      onPressed: () {
                                                        ref.read(navigationProvider.notifier).setIndex(0);
                                                        Navigator.pop(context);
                                                      },
                                                    ),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (sheetContext.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('일정 추가 실패: $e')),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCompactRating(Store store, bool isDark) {
    return Row(
      children: [
        const Icon(Icons.star, color: Colors.amber, size: 20),
        const SizedBox(width: 4),
        Text(
          (store.rating ?? 0.0).toStringAsFixed(1),
          style: GoogleFonts.notoSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        if (store.region != null && store.region!.isNotEmpty) ...[
          const SizedBox(width: 12),
          Icon(Icons.location_on, color: isDark ? Colors.white38 : Colors.grey, size: 18),
          const SizedBox(width: 4),
          Text(
            store.region!,
            style: GoogleFonts.notoSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryChips(List<String> tags, bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return GestureDetector(
          onTap: () {
            ref.read(searchQueryProvider.notifier).state = '#$tag';
            ref.read(navigationProvider.notifier).setIndex(1);
            Navigator.pop(context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF3267A2).withValues(alpha: isDark ? 0.20 : 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF3267A2).withValues(alpha: isDark ? 0.40 : 0.25),
                width: 1,
              ),
            ),
            child: Text(
              '# $tag',
              style: GoogleFonts.notoSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF3267A2),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatMenuValue(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      final str = value.toInt().toString();
      final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      final formatted = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
      return '$formatted원';
    }
    return value.toString();
  }

  Widget _buildMenuBoardSection(Map<String, dynamic> menu, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.restaurant_menu, color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF3267A2), size: 22),
            const SizedBox(width: 8),
            Text(
              "메뉴판",
              style: GoogleFonts.notoSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: menu.entries.map((entry) {
              final isLast = menu.entries.last.key == entry.key;
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: GoogleFonts.notoSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        _formatMenuValue(entry.value),
                        style: GoogleFonts.notoSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF3267A2),
                        ),
                      ),
                    ],
                  ),
                  if (!isLast) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEEEEEE)),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMapSection(Store store, bool isDark) {
    final lat = store.latitude!;
    final lng = store.longitude!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "위치 안내",
          style: GoogleFonts.notoSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        if (kIsWeb)
          Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                GestureBinding.instance.pointerSignalResolver.register(
                  event,
                  (PointerSignalEvent event) {},
                );
              }
            },
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: getWebMap(lat, lng, store.name),
              ),
            ),
          )
        else
          Container(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: NaverMap(
                options: NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: NLatLng(lat, lng),
                    zoom: 15,
                  ),
                  locationButtonEnable: false,
                  indoorEnable: true,
                  consumeSymbolTapEvents: false,
                ),
                forceGesture: true,
                onMapReady: (controller) {
                  final marker = NMarker(
                    id: store.id ?? 'marker',
                    position: NLatLng(lat, lng),
                  );
                  controller.addOverlayAll({marker});
                  final infoWindow =
                      NInfoWindow.onMarker(id: marker.info.id, text: store.name);
                  marker.openInfoWindow(infoWindow);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRatingSection(BuildContext context, Store store, bool isDark) {
    final stats = _RatingStats.fromReviews(store.reviews);
    final user = Supabase.instance.client.auth.currentUser;
    final hasRated = store.id != null &&
        user != null &&
        ref
            .read(storesProvider.notifier)
            .hasUserRatedStore(store.id!, user.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "평점 및 리뷰",
              style: GoogleFonts.notoSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (stats.count > 0)
              Text(
                "평가 ${stats.count}개",
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : Colors.grey[600],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
          ),
          child: Column(
            children: [
              if (stats.count == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Center(
                    child: Text(
                      "아직 평점이 없습니다.\n첫 번째 평점을 남겨보세요!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSans(
                        fontSize: 14,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                        height: 1.5,
                      ),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            stats.finalAvg.toStringAsFixed(1),
                            style: GoogleFonts.notoSans(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return Icon(
                                index < stats.finalAvg.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 18,
                              );
                            }),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "최종 점수 평균",
                            style: GoogleFonts.notoSans(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 80,
                      width: 1,
                      color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                    ),
                    Expanded(
                      flex: 6,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Column(
                          children: [
                            _buildRatingBar("음료", stats.drinkAvg, isDark),
                            const SizedBox(height: 8),
                            _buildRatingBar("위생", stats.hygieneAvg, isDark),
                            const SizedBox(height: 8),
                            _buildRatingBar("분위기", stats.atmosphereAvg, isDark),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: store.id == null || hasRated
                      ? null
                      : () => _showRatingDialog(context, store.id!),
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: Text(
                    hasRated
                        ? "이미 평점을 남겼습니다"
                        : user == null
                            ? "로그인 후 평점 매기기"
                            : stats.count == 0
                                ? "첫 평점 매기기"
                                : "평점 참여하기",
                    style: GoogleFonts.notoSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3267A2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingBar(String label, double rating, bool isDark) {
    return Row(
      children: [
        SizedBox(
          width: 45,
          child: Text(
            label,
            style: GoogleFonts.notoSans(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (rating / 5.0).clamp(0.0, 1.0),
              backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 24,
          child: Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.notoSans(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  void _showRatingDialog(BuildContext context, String storeId) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('평점을 매기려면 로그인이 필요합니다.')),
      );
      ref.read(navigationProvider.notifier).setIndex(2);
      Navigator.pop(context);
      return;
    }

    if (ref
        .read(storesProvider.notifier)
        .hasUserRatedStore(storeId, user.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 이 카페에 평점을 남겼습니다.')),
      );
      return;
    }

    var drink = 5.0;
    var hygiene = 5.0;
    var atmosphere = 5.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pageContext = context;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[300],
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        "카페 평점 매기기",
                        style: GoogleFonts.notoSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "이 카페의 항목별 평점을 매겨주세요.\n(5점 만점)",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _buildRatingCategoryRow(
                        "음료 맛",
                        drink,
                        (val) => setState(() => drink = val),
                        isDark,
                      ),
                      _buildRatingCategoryRow(
                        "위생 상태",
                        hygiene,
                        (val) => setState(() => hygiene = val),
                        isDark,
                      ),
                      _buildRatingCategoryRow(
                        "매장 분위기",
                        atmosphere,
                        (val) => setState(() => atmosphere = val),
                        isDark,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3267A2).withValues(alpha: isDark ? 0.20 : 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "최종 평점 (자동 계산)",
                              style: GoogleFonts.notoSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF3267A2),
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  ((drink + hygiene + atmosphere) / 3).toStringAsFixed(1),
                                  style: GoogleFonts.notoSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF3267A2),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? Colors.white70 : Colors.grey[700],
                                side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                "취소",
                                style: GoogleFonts.notoSans(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(sheetContext);

                                ScaffoldMessenger.of(pageContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '평점을 등록하는 중...',
                                    ),
                                    duration: Duration(milliseconds: 500),
                                  ),
                                );

                                final autoFinal = (drink + hygiene + atmosphere) / 3;
                                try {
                                  await ref
                                      .read(storesProvider.notifier)
                                      .submitRating(
                                        storeId: storeId,
                                        drink: drink,
                                        hygiene: hygiene,
                                        atmosphere: atmosphere,
                                        finalScore: autoFinal,
                                      );
                                } on RatingSubmissionException catch (e) {
                                  if (!mounted) return;
                                  final message = switch (e.code) {
                                    'alreadyRated' =>
                                      '이미 이 카페에 평점을 남겼습니다.',
                                    'saveFailed' =>
                                      e.detail == null
                                          ? '평점 저장에 실패했습니다. 잠시 후 다시 시도해주세요.'
                                          : '평점 저장 실패: ${e.detail}',
                                    _ =>
                                      '평점을 매기려면 로그인이 필요합니다.',
                                  };
                                  ScaffoldMessenger.of(pageContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(message),
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        96,
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (!mounted) return;
                                ScaffoldMessenger.of(pageContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '평점이 성공적으로 등록되었습니다!',
                                      style: GoogleFonts.notoSans(),
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      96,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3267A2),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                "등록",
                                style: GoogleFonts.notoSans(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRatingCategoryRow(
    String title,
    double rating,
    ValueChanged<double> onRatingChanged,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.notoSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.grey[800],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final starValue = index + 1.0;
              return GestureDetector(
                onTap: () => onRatingChanged(starValue),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Icon(
                    starValue <= rating ? Icons.star : Icons.star_border,
                    color:
                        starValue <= rating ? Colors.amber : (isDark ? Colors.white12 : Colors.grey[300]),
                    size: 24,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _RatingStats {
  final double drinkAvg;
  final double hygieneAvg;
  final double atmosphereAvg;
  final double finalAvg;
  final int count;

  const _RatingStats({
    required this.drinkAvg,
    required this.hygieneAvg,
    required this.atmosphereAvg,
    required this.finalAvg,
    required this.count,
  });

  factory _RatingStats.fromReviews(List<dynamic>? reviews) {
    if (reviews == null || reviews.isEmpty) {
      return const _RatingStats(
        drinkAvg: 0,
        hygieneAvg: 0,
        atmosphereAvg: 0,
        finalAvg: 0,
        count: 0,
      );
    }

    var drinkSum = 0.0;
    var hygieneSum = 0.0;
    var atmosphereSum = 0.0;
    var count = 0;

    for (final review in reviews) {
      if (review is! Map) continue;
      drinkSum += _readRating(review['drink']);
      hygieneSum += _readRating(review['hygiene']);
      atmosphereSum += _readRating(review['atmosphere']);
      count++;
    }

    if (count == 0) {
      return const _RatingStats(
        drinkAvg: 0,
        hygieneAvg: 0,
        atmosphereAvg: 0,
        finalAvg: 0,
        count: 0,
      );
    }

    final dAvg = drinkSum / count;
    final hAvg = hygieneSum / count;
    final aAvg = atmosphereSum / count;

    return _RatingStats(
      drinkAvg: dAvg,
      hygieneAvg: hAvg,
      atmosphereAvg: aAvg,
      finalAvg: (dAvg + hAvg + aAvg) / 3, // 3개 평균으로 자동 계산
      count: count,
    );
  }

  static double _readRating(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
