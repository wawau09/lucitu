import 'package:flutter/material.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  String _searchQuery = '';

  String? _getMainImageUrl(Store store) {
    return store.imageUrls.isNotEmpty ? store.imageUrls.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategories = ref.watch(selectedCategoriesProvider);
    final storesAsync = ref.watch(storesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  textAlignVertical: TextAlignVertical.center,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.grey,
                      size: 20,
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 32),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    hintText: "\uCE74\uD398 \uC774\uB984\uC744 \uAC80\uC0C9\uD574\uBCF4\uC138\uC694",
                    hintStyle: GoogleFonts.notoSans(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const CategoryFilterSection(),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Expanded(
              child: storesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) =>
                    Center(child: Text("\uC624\uB958\uAC00 \uBC1C\uC0DD\uD588\uC2B5\uB2C8\uB2E4: $err")),
                data: (storesList) {
                  var stores = List<Store>.from(storesList);

                  if (_searchQuery.isNotEmpty) {
                    stores = stores
                        .where(
                          (store) => store.name
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()),
                        )
                        .toList();
                  }

                  if (selectedCategories.isNotEmpty) {
                    stores = stores.where((store) {
                      final storeCats = getStoreCategories(store);
                      return ref
                          .read(selectedCategoriesProvider.notifier)
                          .matchesAny(storeCats);
                    }).toList();
                  }

                  if (stores.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildCafeList(stores);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCafeList(List<Store> stores) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: stores.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: Color(0xFFEEEEEE),
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
                        return Container(color: Colors.grey[100]);
                      }
                      return Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: Colors.grey[100]),
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
                            color: Colors.black87,
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
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                store.categoryTags.isNotEmpty
                                    ? store.categoryTags.take(2).join(' · ')
                                    : '',
                                style: GoogleFonts.notoSans(
                                  fontSize: 13,
                                  color: Colors.grey[600],
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
                                          '\uCC1C \uAE30\uB2A5\uC744 \uC0AC\uC6A9\uD558\uB824\uBA74 \uB85C\uADF8\uC778\uC774 \uD544\uC694\uD569\uB2C8\uB2E4.',
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
                                        .toggleFavorite(store.id!);
                                  }
                                },
                                icon: Icon(
                                  isFavorited
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFavorited
                                      ? Colors.redAccent
                                      : Colors.grey[400],
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            "\uC544\uC9C1 \uB4F1\uB85D\uB41C \uCE74\uD398\uAC00 \uC5C6\uB124\uC694!",
            style: GoogleFonts.notoSans(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
