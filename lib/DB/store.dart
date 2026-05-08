class Store {
  String? id;
  String name;
  String folderName;
  int? imageId;
  String? imageUrl;
  String? imagePath;
  String? location;
  double? rating;

  Store({
    this.id,
    required this.name,
    required this.folderName,
    this.imageId,
    this.imageUrl,
    this.imagePath,
    this.location,
    this.rating,
  });

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
    
    final double? resolvedRating = map['rating'] is num 
        ? (map['rating'] as num).toDouble() 
        : double.tryParse(map['rating']?.toString() ?? '');

    return Store(
      id: rawId?.toString(),
      name: map['name'] ?? '이름 없음',
      folderName: resolvedFolderName,
      imageId: resolvedImageId,
      imageUrl: resolvedImageUrl,
      imagePath: resolvedImagePath,
      location: map['location']?.toString(),
      rating: resolvedRating,
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
    };
  }
}