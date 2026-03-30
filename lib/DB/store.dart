class Store {
  String? id;
  String name;
  String folderName;
  String? imageUrl;
  String? imagePath;

  Store({
    this.id,
    required this.name,
    required this.folderName,
    this.imageUrl,
    this.imagePath,
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

    return Store(
      id: rawId?.toString(),
      name: map['name'] ?? '이름 없음',
      folderName: resolvedFolderName,
      imageUrl: resolvedImageUrl,
      imagePath: resolvedImagePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'folder_name': folderName,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
      if (imagePath != null && imagePath!.isNotEmpty) 'image_path': imagePath,
    };
  }
}