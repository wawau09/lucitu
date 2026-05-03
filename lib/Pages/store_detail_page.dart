import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/supabase_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
class StoreDetailPage extends StatefulWidget {
  final Store store;

  const StoreDetailPage({Key? key, required this.store}) : super(key: key);

  @override
  State<StoreDetailPage> createState() => _StoreDetailPageState();
}

class _StoreDetailPageState extends State<StoreDetailPage> {
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
      backgroundColor: const Color(0xFFF8F5EF),
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
                            color: Colors.grey[100], // light background to better see contain bounds
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
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: Material(
                          color: Colors.white.withOpacity(0.8),
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
            
            // Name and Details Container
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.store.name,
                    style: GoogleFonts.notoSans(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.2,
                    ),
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
                  
                  // Placeholder for future information
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
