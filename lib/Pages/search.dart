import 'package:flutter/material.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/DB/store_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:placelist/supabase_config.dart';
import 'package:placelist/Pages/store_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => Search();
}

class Search extends State<SearchPage> {
  final storesDatabase = StoreDatabase();
  final SupabaseClient _client = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  List<Store> _filteredStores = [];
  late Future<List<Store>> _storesFuture;

  @override
  void initState() {
    super.initState();
    _storesFuture = storesDatabase.getStores();
  }

  Future<String> getImageUrl(Store store) async {
    if (store.imageUrl != null && store.imageUrl!.isNotEmpty) {
      return store.imageUrl!;
    }

    final storage = _client.storage.from(supabaseStorageBucket);

    if (store.imagePath != null && store.imagePath!.isNotEmpty) {
      try {
        return await storage.createSignedUrl(store.imagePath!, 60 * 60);
      } catch (_) {}
      try {
        return storage.getPublicUrl(store.imagePath!);
      } catch (_) {}
    }

    final String imageToken =
        (store.imageId != null && store.imageId! > 0) ? '${store.imageId}' : '1';

    final candidates = <String>[
      '${store.folderName}/1.jpeg',
      '${store.folderName}/1.jpg',
      '${store.folderName}/1.png',
      '${store.folderName}/1',
      '${store.folderName}/$imageToken.jpeg',
      '${store.folderName}/$imageToken.jpg',
      '${store.folderName}/$imageToken.png',
      '${store.folderName}/$imageToken',
    ];

    for (final path in candidates) {
      try {
        return await storage.createSignedUrl(path, 60 * 60);
      } catch (_) {
        try {
          return storage.getPublicUrl(path);
        } catch (_) {
          continue;
        }
      }
    }

    return '';
  }

  Widget buildCard(Store store) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              StoreDetailPage(store: store),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: animation.drive(
                Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeOutCubic)),
              ),
              child: child,
            );
          },
        ),
      );
    },
    child: Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded( 
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: FutureBuilder<String>(
                    future: getImageUrl(store), 
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Icon(Icons.broken_image, size: 50, color: Colors.grey);
                      }
                      return Image.network(
                        snapshot.data!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          (store.rating ?? 0.0).toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    store.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.favorite_border,
                    color: Colors.grey,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  void _filterStores(String query, List<Store> stores) {
    setState(() {
      if (query.isEmpty) {
        _filteredStores = stores;
      } else {
        _filteredStores = stores.where((store) =>
            store.name.toLowerCase().contains(query.toLowerCase())
        ).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<Store>>(
        future: _storesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stores = snapshot.data!;
          
          if (_filteredStores.isEmpty && _searchController.text.isEmpty) {
            _filteredStores = stores;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (query) => _filterStores(query, stores),
                  decoration: InputDecoration(
                    hintText: '가게 이름으로 검색...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _filteredStores.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.isEmpty 
                                ? '가게가 없습니다' 
                                : '검색 결과가 없습니다',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : GridView.builder(
                          itemCount: _filteredStores.length,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 250, 
                            childAspectRatio: 0.8,   
                            crossAxisSpacing: 16,    
                            mainAxisSpacing: 16,     
                          ),
                          itemBuilder: (context, index) {
                            return buildCard(_filteredStores[index]); 
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    ),
   );
  }
}