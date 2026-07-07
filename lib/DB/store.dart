class Store {
  String? id;
  String name;
  double? latitude;
  double? longitude;
  List<String> categoryTags;
  List<String> imageUrls;
  List<dynamic>? reviews;
  double? rating;
  String? region;
  Map<String, dynamic>? menuBoard;

  Store({
    this.id,
    required this.name,
    this.latitude,
    this.longitude,
    List<String>? categoryTags,
    List<String>? imageUrls,
    this.reviews,
    this.rating,
    this.region,
    this.menuBoard,
  })  : categoryTags = categoryTags ?? [],
        imageUrls = imageUrls ?? [];

  Store copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    List<String>? categoryTags,
    List<String>? imageUrls,
    List<dynamic>? reviews,
    double? rating,
    String? region,
    Map<String, dynamic>? menuBoard,
  }) {
    return Store(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      categoryTags: categoryTags ?? this.categoryTags,
      imageUrls: imageUrls ?? this.imageUrls,
      reviews: reviews ?? this.reviews,
      rating: rating ?? this.rating,
      region: region ?? this.region,
      menuBoard: menuBoard ?? this.menuBoard,
    );
  }

  factory Store.fromMap(Map<String, dynamic> map) {
    final dynamic rawId = map['id'];

    // category_tags: text[] from Supabase
    final List<String> resolvedCategoryTags = () {
      final raw = map['category_tags'];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return <String>[];
    }();

    // image_urls: text[] from Supabase
    final List<String> resolvedImageUrls = () {
      final raw = map['image_urls'];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return <String>[];
    }();

    final List<dynamic>? resolvedReviews =
        map['reviews'] is List ? map['reviews'] as List<dynamic> : null;

    double? resolvedRating = map['rating'] is num
        ? (map['rating'] as num).toDouble()
        : double.tryParse(map['rating']?.toString() ?? '');

    if (resolvedReviews != null && resolvedReviews.isNotEmpty) {
      double totalDrink = 0.0;
      double totalHygiene = 0.0;
      double totalAtmosphere = 0.0;
      int count = 0;
      for (var rev in resolvedReviews) {
        if (rev is Map) {
          final drink = rev['drink'];
          final hygiene = rev['hygiene'];
          final atmosphere = rev['atmosphere'];
          if (drink is num && hygiene is num && atmosphere is num) {
            totalDrink += drink.toDouble();
            totalHygiene += hygiene.toDouble();
            totalAtmosphere += atmosphere.toDouble();
            count++;
          }
        }
      }
      if (count > 0) {
        // 음료, 위생, 분위기 3개 평균
        resolvedRating =
            (totalDrink + totalHygiene + totalAtmosphere) / (count * 3);
      }
    }

    final double? resolvedLat = map['latitude'] is num
        ? (map['latitude'] as num).toDouble()
        : double.tryParse(map['latitude']?.toString() ?? '');

    final double? resolvedLng = map['longitude'] is num
        ? (map['longitude'] as num).toDouble()
        : double.tryParse(map['longitude']?.toString() ?? '');

    final Map<String, dynamic>? resolvedMenuBoard = map['menu_board'] is Map
        ? Map<String, dynamic>.from(map['menu_board'] as Map)
        : null;

    return Store(
      id: rawId?.toString(),
      name: map['name']?.toString() ?? '이름 없음',
      latitude: resolvedLat,
      longitude: resolvedLng,
      categoryTags: resolvedCategoryTags,
      imageUrls: resolvedImageUrls,
      reviews: resolvedReviews,
      rating: resolvedRating,
      region: map['region']?.toString(),
      menuBoard: resolvedMenuBoard,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'category_tags': categoryTags,
      'image_urls': imageUrls,
      if (reviews != null) 'reviews': reviews,
      if (region != null) 'region': region,
      if (menuBoard != null) 'menu_board': menuBoard,
    };
  }
}