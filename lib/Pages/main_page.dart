import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:placelist/DB/store_database.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:placelist/Pages/store_detail_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
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
    final storage = _client.storage.from(supabaseStorageBucket);
    final path = '${store.folderName}/1.jpeg';
    try {
      return storage.getPublicUrl(path);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 타이틀
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Text(
                "Lucitu",
                style: GoogleFonts.poppins(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            // 검색창 (항상 표시)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Container(
                height: 48,
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
                    prefixIcon: const Icon(Icons.search, color: Colors.black, size: 24),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 48,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    hintText: "Search the lucy",
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
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
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
            margin: const EdgeInsets.only(bottom: 14),
            color: Colors.white,
            elevation: 3,
            shadowColor: Colors.black.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                // 카드 상단 이미지
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 230,
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
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 16,
                  ),
                  child: Text(
                    store.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
          Icon(Icons.map_outlined, size: 100, color: Colors.grey[200]),
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
