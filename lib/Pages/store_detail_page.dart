import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/supabase_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:placelist/providers/favorites_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _imagesFuture = _getStoreImageUrls(widget.store);
  }

  Future<List<String>> _getStoreImageUrls(Store store) async {
    final storage = _client.storage.from(supabaseStorageBucket);
    List<String> urls = [];
    try {
      final files = await storage.list(path: store.folderName);
      var imageFiles = files.where((f) => 
        f.name.toLowerCase().endsWith('.jpeg') || 
        f.name.toLowerCase().endsWith('.jpg') || 
        f.name.toLowerCase().endsWith('.png')
      ).toList();
      
      imageFiles.sort((a, b) {
        int numA = int.tryParse(a.name.split('.').first) ?? 0;
        int numB = int.tryParse(b.name.split('.').first) ?? 0;
        return numA.compareTo(numB);
      });

      for (var file in imageFiles) {
        final path = '${store.folderName}/${file.name}';
        urls.add(storage.getPublicUrl(path));
      }
    } catch (e) {
      for (int i = 1; i <= 2; i++) {
        final path = '${store.folderName}/$i.jpeg';
        urls.add(storage.getPublicUrl(path));
      }
    }
    
    if (urls.isEmpty) {
      final path = '${store.folderName}/1.jpeg';
      urls.add(storage.getPublicUrl(path));
    }
    
    return urls;
  }

  @override
  Widget build(BuildContext context) {
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
            // Top Image Header
            SizedBox(
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
                                  child: Icon(Icons.broken_image, color: Colors.grey, size: 60),
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
                      // 평점 배지를 이미지 위에서 제거했습니다.
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
                                      iconTheme: const IconThemeData(color: Colors.white),
                                    ),
                                    body: PanoramaViewer(
                                      child: Image.asset('assets/relax_inn_seaview_suite_4k.jpg'),
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.threed_rotation, size: 20, color: Colors.black87),
                                  const SizedBox(width: 4),
                                  Text(
                                    "파노라마",
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
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                          final isFavorited = widget.store.id != null && favoriteIds.contains(widget.store.id);
                          
                          return IconButton(
                            onPressed: () {
                              if (widget.store.id != null) {
                                ref.read(favoritesProvider.notifier).toggleFavorite(widget.store.id!);
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
                  ),
                  const SizedBox(height: 8),
                  // 평점을 카페명 밑으로 이동
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        (widget.store.rating ?? 0.0).toStringAsFixed(1),
                        style: GoogleFonts.notoSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
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
                    "상세 소개",
                    style: GoogleFonts.notoSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "${widget.store.name}에 대한 정보가 업데이트될 예정입니다.",
                    style: GoogleFonts.notoSans(
                      fontSize: 15,
                      height: 1.6,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
