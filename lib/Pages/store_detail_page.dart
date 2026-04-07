import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/supabase_config.dart';
import 'package:google_fonts/google_fonts.dart';

class StoreDetailPage extends StatefulWidget {
  final Store store;

  const StoreDetailPage({Key? key, required this.store}) : super(key: key);

  @override
  State<StoreDetailPage> createState() => _StoreDetailPageState();
}

class _StoreDetailPageState extends State<StoreDetailPage> {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> _getMainImageUrl(Store store) async {
    final storage = _client.storage.from(supabaseStorageBucket);
    final path = '${store.folderName}/1.jpeg';
    try {
      return await storage.createSignedUrl(path, 60 * 60);
    } catch (_) {
      try {
        return storage.getPublicUrl(path);
      } catch (_) {
        return '';
      }
    }
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
              child: FutureBuilder<String>(
                future: _getMainImageUrl(widget.store),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.image_outlined, color: Colors.white, size: 80),
                      ),
                    );
                  }
                  return Image.network(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey, size: 60),
                      ),
                    ),
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
                      fontSize: 32,
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
