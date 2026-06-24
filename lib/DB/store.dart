class Store {
  String? id;
  String name;
  double? latitude;
  double? longitude;
  List<String> categoryTags;
  List<String> imageUrls;
  List<dynamic>? reviews;
  double? rating;

  Store({
    this.id,
    required this.name,
    this.latitude,
    this.longitude,
    List<String>? categoryTags,
    List<String>? imageUrls,
    this.reviews,
    this.rating,
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
      double totalFinal = 0.0;
      int count = 0;
      for (var rev in resolvedReviews) {
        if (rev is Map) {
          final val = rev['final'] ?? rev['finalScore'];
          if (val is num) {
            totalFinal += val.toDouble();
            count++;
          }
        }
      }
      if (count > 0) {
        resolvedRating = totalFinal / count;
      }
    }

    final double? resolvedLat = map['latitude'] is num
        ? (map['latitude'] as num).toDouble()
        : double.tryParse(map['latitude']?.toString() ?? '');

    final double? resolvedLng = map['longitude'] is num
        ? (map['longitude'] as num).toDouble()
        : double.tryParse(map['longitude']?.toString() ?? '');

    return Store(
      id: rawId?.toString(),
      name: map['name']?.toString() ?? '이름 없음',
      latitude: resolvedLat,
      longitude: resolvedLng,
      categoryTags: resolvedCategoryTags,
      imageUrls: resolvedImageUrls,
      reviews: resolvedReviews,
      rating: resolvedRating,
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
    };
  }
}