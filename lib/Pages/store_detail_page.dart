import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/Pages/map_stub.dart'
    if (dart.library.html) 'package:placelist/Pages/map_web.dart';
import 'package:placelist/providers/favorites_provider.dart';
import 'package:placelist/providers/navigation_provider.dart';
import 'package:placelist/providers/stores_provider.dart';
import 'package:placelist/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoreDetailPage extends ConsumerStatefulWidget {
  final Store store;

  const StoreDetailPage({super.key, required this.store});

  @override
  ConsumerState<StoreDetailPage> createState() => _StoreDetailPageState();
}

class _StoreDetailPageState extends ConsumerState<StoreDetailPage> {
  final SupabaseClient _client = Supabase.instance.client;
  int _currentPage = 0;
  late Future<List<String>> _imagesFuture;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _imagesFuture = _getStoreImageUrls(widget.store);
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    if (widget.store.id == null) return;
    try {
      final data = await _client
          .from('stores_map_view')
          .select('latitude, longitude')
          .eq('id', widget.store.id!)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _latitude = data['latitude'] is num
              ? (data['latitude'] as num).toDouble()
              : double.tryParse(data['latitude']?.toString() ?? '');
          _longitude = data['longitude'] is num
              ? (data['longitude'] as num).toDouble()
              : double.tryParse(data['longitude']?.toString() ?? '');
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch location: $e');
    }
  }

  Future<List<String>> _getStoreImageUrls(Store store) async {
    final storage = _client.storage.from(supabaseStorageBucket);
    final urls = <String>[];
    try {
      final files = await storage.list(path: store.folderName);
      final imageFiles = files
          .where(
            (file) =>
                file.name.toLowerCase().endsWith('.jpeg') ||
                file.name.toLowerCase().endsWith('.jpg') ||
                file.name.toLowerCase().endsWith('.png'),
          )
          .toList();

      imageFiles.sort((a, b) {
        final numA = int.tryParse(a.name.split('.').first) ?? 0;
        final numB = int.tryParse(b.name.split('.').first) ?? 0;
        return numA.compareTo(numB);
      });

      for (final file in imageFiles) {
        urls.add(storage.getPublicUrl('${store.folderName}/${file.name}'));
      }
    } catch (e) {
      for (var i = 1; i <= 2; i++) {
        urls.add(storage.getPublicUrl('${store.folderName}/$i.jpeg'));
      }
    }

    if (urls.isEmpty) {
      urls.add(storage.getPublicUrl('${store.folderName}/1.jpeg'));
    }

    return urls;
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImageHeader(),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleRow(context),
                  const SizedBox(height: 8),
                  _buildCompactRating(store),
                  const SizedBox(height: 8),
                  if (store.location != null) _buildLocationRow(store),
                  const SizedBox(height: 16),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.lightBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "\uC0C1\uC138 \uC18C\uAC1C",
                    style: GoogleFonts.notoSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "${store.name}\uC5D0 \uB300\uD55C \uC815\uBCF4\uAC00 \uC5C5\uB370\uC774\uD2B8\uB420 \uC608\uC815\uC785\uB2C8\uB2E4.",
                    style: GoogleFonts.notoSans(
                      fontSize: 15,
                      height: 1.6,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildRatingSection(context, store),
                  const SizedBox(height: 32),
                  if (_latitude != null && _longitude != null) ...[
                    _buildMapSection(store),
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

  Widget _buildImageHeader() {
    return SizedBox(
      height: 400,
      width: double.infinity,
      child: FutureBuilder<List<String>>(
        future: _imagesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Container(
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.image_outlined, color: Colors.white, size: 80),
              ),
            );
          }

          final imageUrls = snapshot.data!;

          return Stack(
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
                    color: Colors.grey[100],
                    child: Image.network(
                      imageUrls[index],
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.grey,
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
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 16,
                bottom: 16,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.8),
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
                          const Icon(
                            Icons.threed_rotation,
                            size: 20,
                            color: Colors.black87,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "\uD30C\uB178\uB77C\uB9C8",
                            style: GoogleFonts.notoSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTitleRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            widget.store.name,
            style: GoogleFonts.notoSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.2,
            ),
          ),
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
                    const SnackBar(content: Text('\uCC1C \uAE30\uB2A5\uC744 \uC0AC\uC6A9\uD558\uB824\uBA74 \uB85C\uADF8\uC778\uC774 \uD544\uC694\uD569\uB2C8\uB2E4.')),
                  );
                  ref.read(navigationProvider.notifier).setIndex(2);
                  Navigator.pop(context);
                  return;
                }
                if (widget.store.id != null) {
                  ref
                      .read(favoritesProvider.notifier)
                      .toggleFavorite(widget.store.id!);
                }
              },
              icon: Icon(
                isFavorited ? Icons.favorite : Icons.favorite_border,
                color: isFavorited ? Colors.redAccent : Colors.black87,
                size: 28,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCompactRating(Store store) {
    return Row(
      children: [
        const Icon(Icons.star, color: Colors.amber, size: 20),
        const SizedBox(width: 4),
        Text(
          (store.rating ?? 0.0).toStringAsFixed(1),
          style: GoogleFonts.notoSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow(Store store) {
    return Row(
      children: [
        const Icon(Icons.location_on, color: Colors.grey, size: 18),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            store.location!,
            style: GoogleFonts.notoSans(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapSection(Store store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "\uC704\uCE58 \uC548\uB0B4",
          style: GoogleFonts.notoSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        if (kIsWeb)
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: getWebMap(_latitude!, _longitude!, store.name),
            ),
          )
        else
          Container(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: NaverMap(
                options: NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: NLatLng(_latitude!, _longitude!),
                    zoom: 15,
                  ),
                  locationButtonEnable: false,
                  indoorEnable: true,
                  consumeSymbolTapEvents: false,
                ),
                onMapReady: (controller) {
                  final marker = NMarker(
                    id: store.id ?? 'marker',
                    position: NLatLng(_latitude!, _longitude!),
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

  Widget _buildRatingSection(BuildContext context, Store store) {
    final stats = _RatingStats.fromReviews(store.reviews);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "\uD3C9\uC810 \uBC0F \uB9AC\uBDF0",
              style: GoogleFonts.notoSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (stats.count > 0)
              Text(
                "\uD3C9\uAC00 ${stats.count}\uAC1C",
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            children: [
              if (stats.count == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Center(
                    child: Text(
                      "\uC544\uC9C1 \uD3C9\uC810\uC774 \uC5C6\uC2B5\uB2C8\uB2E4.\n\uCCAB \uBC88\uC9F8 \uD3C9\uC810\uC744 \uB0A8\uACA8\uBCF4\uC138\uC694!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSans(
                        fontSize: 14,
                        color: Colors.grey[500],
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
                              color: Colors.black87,
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
                            "\uCD5C\uC885 \uC810\uC218 \uD3C9\uADE0",
                            style: GoogleFonts.notoSans(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 80,
                      width: 1,
                      color: Colors.grey[200],
                    ),
                    Expanded(
                      flex: 6,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Column(
                          children: [
                            _buildRatingBar("\uC74C\uB8CC", stats.drinkAvg),
                            const SizedBox(height: 8),
                            _buildRatingBar("\uC704\uC0DD", stats.hygieneAvg),
                            const SizedBox(height: 8),
                            _buildRatingBar("\uBD84\uC704\uAE30", stats.atmosphereAvg),
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
                  onPressed: store.id == null
                      ? null
                      : () => _showRatingDialog(context, store.id!),
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: Text(
                    stats.count == 0 ? "\uCCAB \uD3C9\uC810 \uB9E4\uAE30\uAE30" : "\uD3C9\uC810 \uCC38\uC5EC\uD558\uAE30",
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

  Widget _buildRatingBar(String label, double rating) {
    return Row(
      children: [
        SizedBox(
          width: 45,
          child: Text(
            label,
            style: GoogleFonts.notoSans(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (rating / 5.0).clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
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
              color: Colors.black87,
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
        const SnackBar(content: Text('\uD3C9\uC810\uC744 \uB9E4\uAE30\uB824\uBA74 \uB85C\uADF8\uC778\uC774 \uD544\uC694\uD569\uB2C8\uB2E4.')),
      );
      ref.read(navigationProvider.notifier).setIndex(2);
      Navigator.pop(context);
      return;
    }

    var drink = 5.0;
    var hygiene = 5.0;
    var atmosphere = 5.0;
    var finalScore = 5.0;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Center(
                child: Text(
                  "\uCE74\uD398 \uD3C9\uC810 \uB9E4\uAE30\uAE30",
                  style: GoogleFonts.notoSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "\uC774 \uCE74\uD398\uC758 \uD56D\uBAA9\uBCC4 \uD3C9\uC810\uC744 \uB9E4\uACA8\uC8FC\uC138\uC694.\n(5\uC810 \uB9CC\uC810)",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSans(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildRatingCategoryRow(
                      "\uC74C\uB8CC \uB9DB",
                      drink,
                      (val) => setState(() => drink = val),
                    ),
                    _buildRatingCategoryRow(
                      "\uC704\uC0DD \uC0C1\uD0DC",
                      hygiene,
                      (val) => setState(() => hygiene = val),
                    ),
                    _buildRatingCategoryRow(
                      "\uB9E4\uC7A5 \uBD84\uC704\uAE30",
                      atmosphere,
                      (val) => setState(() => atmosphere = val),
                    ),
                    const Divider(height: 32),
                    _buildRatingCategoryRow(
                      "\uCD5C\uC885 \uC810\uC218",
                      finalScore,
                      (val) => setState(() => finalScore = val),
                      isFinal: true,
                    ),
                  ],
                ),
              ),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "\uCDE8\uC18C",
                          style: GoogleFonts.notoSans(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('\uD3C9\uC810\uC744 \uB4F1\uB85D\uD558\uB294 \uC911...'),
                              duration: Duration(milliseconds: 500),
                            ),
                          );

                          await ref.read(storesProvider.notifier).submitRating(
                                storeId: storeId,
                                drink: drink,
                                hygiene: hygiene,
                                atmosphere: atmosphere,
                                finalScore: finalScore,
                              );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '\uD3C9\uC810\uC774 \uC131\uACF5\uC801\uC73C\uB85C \uB4F1\uB85D\uB418\uC5C8\uC2B5\uB2C8\uB2E4!',
                                  style: GoogleFonts.notoSans(),
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3267A2),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "\uB4F1\uB85D",
                          style: GoogleFonts.notoSans(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRatingCategoryRow(
    String title,
    double rating,
    ValueChanged<double> onRatingChanged, {
    bool isFinal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.notoSans(
              fontSize: isFinal ? 16 : 14,
              fontWeight: isFinal ? FontWeight.bold : FontWeight.w500,
              color: isFinal ? Colors.black87 : Colors.grey[800],
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
                        starValue <= rating ? Colors.amber : Colors.grey[300],
                    size: isFinal ? 28 : 24,
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
    var finalSum = 0.0;
    var count = 0;

    for (final review in reviews) {
      if (review is! Map) continue;
      drinkSum += _readRating(review['drink']);
      hygieneSum += _readRating(review['hygiene']);
      atmosphereSum += _readRating(review['atmosphere']);
      finalSum += _readRating(review['final'] ?? review['finalScore']);
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

    return _RatingStats(
      drinkAvg: drinkSum / count,
      hygieneAvg: hygieneSum / count,
      atmosphereAvg: atmosphereSum / count,
      finalAvg: finalSum / count,
      count: count,
    );
  }

  static double _readRating(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
