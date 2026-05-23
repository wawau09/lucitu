class Store {
  String? id;
  String name;
  String folderName;
  int? imageId;
  String? imageUrl;
  String? imagePath;
  String? location;
  double? rating;
  double? latitude;
  double? longitude;
  List<dynamic>? reviews;

  Store({
    this.id,
    required this.name,
    required this.folderName,
    this.imageId,
    this.imageUrl,
    this.imagePath,
    this.location,
    this.rating,
    this.latitude,
    this.longitude,
    this.reviews,
  });

  Store copyWith({
    String? id,
    String? name,
    String? folderName,
    int? imageId,
    String? imageUrl,
    String? imagePath,
    String? location,
    double? rating,
    double? latitude,
    double? longitude,
    List<dynamic>? reviews,
  }) {
    return Store(
      id: id ?? this.id,
      name: name ?? this.name,
      folderName: folderName ?? this.folderName,
      imageId: imageId ?? this.imageId,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      location: location ?? this.location,
      rating: rating ?? this.rating,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      reviews: reviews ?? this.reviews,
    );
  }

  factory Store.fromMap(Map<String, dynamic> map) {
    final dynamic rawId = map['id'];
    final String resolvedFolderName = (map['folder_name'] ??
            map['folderName'] ??
            map['folder'] ??
            map['category'] ??
            'default_folder')
        .toString();
    final String? resolvedImageUrl = (map['image_url'] ??
            map['imageUrl'] ??
            map['thumbnail_url'] ??
            map['photo_url'])
        ?.toString();
    final String? resolvedImagePath = (map['image_path'] ??
            map['imagePath'] ??
            map['thumbnail_path'] ??
            map['photo_path'])
        ?.toString();
    final int? resolvedImageId = map['image_id'] is int
        ? map['image_id'] as int
        : int.tryParse(map['image_id']?.toString() ?? '');
    
    final List<dynamic>? resolvedReviews = map['reviews'] is List
        ? map['reviews'] as List<dynamic>
        : null;

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
      name: map['name'] ?? '이름 없음',
      folderName: resolvedFolderName,
      imageId: resolvedImageId,
      imageUrl: resolvedImageUrl,
      imagePath: resolvedImagePath,
      location: map['location']?.toString(),
      rating: resolvedRating,
      latitude: resolvedLat,
      longitude: resolvedLng,
      reviews: resolvedReviews,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'folder_name': folderName,
      if (imageId != null) 'image_id': imageId,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
      if (imagePath != null && imagePath!.isNotEmpty) 'image_path': imagePath,
      if (location != null) 'location': location,
      if (rating != null) 'rating': rating,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (reviews != null) 'reviews': reviews,
    };
  }
}