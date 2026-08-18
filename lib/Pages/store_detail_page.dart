import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/Pages/map_stub.dart'
    if (dart.library.html) 'package:placelist/Pages/map_web.dart';
import 'package:placelist/providers/cart_provider.dart';
import 'package:placelist/providers/category_provider.dart';
import 'package:placelist/providers/favorites_provider.dart';
import 'package:placelist/providers/navigation_provider.dart';
import 'package:placelist/providers/order_provider.dart';
import 'package:placelist/providers/stores_provider.dart';
import 'package:placelist/utils/currency_formatter.dart';
import 'package:placelist/widgets/map_marker.dart';
import 'package:placelist/widgets/order/cart_sheet.dart';
import 'package:placelist/widgets/order/menu_option_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:placelist/widgets/store_detail/add_to_plan_sheet.dart';
import 'package:placelist/widgets/store_detail/store_detail_image_header.dart';
import 'package:placelist/widgets/store_detail/store_detail_menu_board.dart';

class StoreDetailPage extends ConsumerStatefulWidget {
  final Store store;

  const StoreDetailPage({super.key, required this.store});

  @override
  ConsumerState<StoreDetailPage> createState() => _StoreDetailPageState();
}

class _StoreDetailPageState extends ConsumerState<StoreDetailPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _orderSectionKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToOrderSection() {
    final context = _orderSectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
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
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StoreDetailImageHeader(store: store, isDark: isDark),
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
                    "상세 소개",
                    style: GoogleFonts.notoSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "${store.name}은(는) ${store.region != null && store.region!.isNotEmpty ? '${store.region}에' : '좋은 위치에'} 위치한 공간입니다. ${store.categoryTags.isNotEmpty ? '\'${store.categoryTags.join(', ')}\' 분위기를 느껴보세요.' : '다양한 메뉴와 아늑한 공간을 제공합니다.'}",
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

                  // In-App Order Section
                  KeyedSubtree(
                    key: _orderSectionKey,
                    child: _buildOrderSection(context, ref, store, isDark),
                  ),
                  const SizedBox(height: 32),

                  if (store.menuBoard != null && store.menuBoard!.isNotEmpty) ...[
                    StoreDetailMenuBoard(menu: store.menuBoard!, isDark: isDark),
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
      bottomNavigationBar: _buildStickyCartBar(context, ref, store, isDark),
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
              onPressed: () => showAddToPlanSheet(context, ref, widget.store),
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
                onMapReady: (controller) async {
                  final marker = await buildCustomMarker(
                    context: context,
                    store: store,
                    isSelected: true,
                    isDark: Theme.of(context).brightness == Brightness.dark,
                  );
                  controller.addOverlayAll({marker});
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
        if (store.reviews != null &&
            store.reviews!.any((r) => r is Map && r['comment'] != null && r['comment'].toString().trim().isNotEmpty)) ...[
          const SizedBox(height: 20),
          Text(
            "방문 후기 목록",
            style: GoogleFonts.notoSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: store.reviews!
                .where((r) => r is Map && r['comment'] != null && r['comment'].toString().trim().isNotEmpty)
                .length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final reviewList = store.reviews!
                  .where((r) => r is Map && r['comment'] != null && r['comment'].toString().trim().isNotEmpty)
                  .toList();
              final review = reviewList[index] as Map;
              final comment = review['comment']?.toString() ?? '';
              final finalScore = (review['final'] ?? review['final_score'] ?? 0.0);
              final scoreNum = (finalScore is num) ? finalScore.toDouble() : double.tryParse(finalScore.toString()) ?? 0.0;
              final createdAtStr = review['created_at']?.toString();
              String dateFormatted = '';
              if (createdAtStr != null) {
                final dt = DateTime.tryParse(createdAtStr);
                if (dt != null) {
                  dateFormatted = '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
                }
              }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              scoreNum.toStringAsFixed(1),
                              style: GoogleFonts.notoSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        if (dateFormatted.isNotEmpty)
                          Text(
                            dateFormatted,
                            style: GoogleFonts.notoSans(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      comment,
                      style: GoogleFonts.notoSans(
                        fontSize: 14,
                        height: 1.4,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
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
    final commentController = TextEditingController();
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
                        "카페 평점 & 한 줄 후기 매기기",
                        style: GoogleFonts.notoSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "이 카페의 항목별 평점과 방문 후기를 남겨주세요.\n(5점 만점)",
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
                      const SizedBox(height: 16),
                      TextField(
                        controller: commentController,
                        maxLines: 3,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: "카페 방문 후기나 솔직한 의견을 남겨주세요 (선택사항)",
                          hintStyle: GoogleFonts.notoSans(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.grey[500],
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(12),
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
                                final commentText = commentController.text;
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
                                        comment: commentText,
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

  Widget _buildOrderSection(
    BuildContext context,
    WidgetRef ref,
    Store store,
    bool isDark,
  ) {
    final menusAsync = ref.watch(storeMenusProvider(store.id ?? 'default'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.coffee_rounded, color: Color(0xFF6C63FF), size: 22),
                const SizedBox(width: 8),
                Text(
                  "실시간 픽업 주문",
                  style: GoogleFonts.notoSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '앱 전용 주문 가능',
                style: GoogleFonts.notoSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6C63FF),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        menusAsync.when(
          data: (menus) {
            if (menus.isEmpty) {
              return Text(
                '등록된 주문 메뉴가 없습니다.',
                style: GoogleFonts.notoSans(color: Colors.grey),
              );
            }

            return Column(
              children: menus.map((menuItem) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF9FAFB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => MenuOptionSheet(
                          storeId: store.id ?? 'default_store',
                          storeName: store.name,
                          menuItem: menuItem,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          if (menuItem.imageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                menuItem.imageUrl!,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 72,
                                  height: 72,
                                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                                  child: const Icon(Icons.coffee, color: Colors.grey),
                                ),
                              ),
                            ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white12 : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        menuItem.category,
                                        style: GoogleFonts.notoSans(
                                          fontSize: 10,
                                          color: isDark ? Colors.white70 : Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        menuItem.name,
                                        style: GoogleFonts.notoSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (menuItem.description != null &&
                                    menuItem.description!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    menuItem.description!,
                                    style: GoogleFonts.notoSans(
                                      fontSize: 12,
                                      color: isDark ? Colors.white54 : Colors.grey[600],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  '${formatCurrency(menuItem.price)}원',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF6C63FF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '담기',
                              style: GoogleFonts.notoSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text('메뉴 불러오기 실패: $err'),
        ),
      ],
    );
  }

  Widget? _buildStickyCartBar(
    BuildContext context,
    WidgetRef ref,
    Store store,
    bool isDark,
  ) {
    final cartState = ref.watch(cartProvider);
    final hasItemsInThisStore =
        cartState.storeId == (store.id ?? 'default_store') && !cartState.isEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              if (hasItemsInThisStore) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const CartSheet(),
                );
              } else {
                _scrollToOrderSection();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasItemsInThisStore
                      ? Icons.shopping_bag_rounded
                      : Icons.local_cafe_rounded,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  hasItemsInThisStore
                      ? '장바구니 보기 (${cartState.totalCount}개 · ${formatCurrency(cartState.totalAmount)}원)'
                      : '☕ 픽업 주문하기',
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
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
