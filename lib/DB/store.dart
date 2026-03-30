class Store {
  String? id;
  String name;
  String folderName;

  Store({
    this.id,
    required this.name,
    required this.folderName,
  });

  factory Store.fromMap(Map<String, dynamic> map) {
    final dynamic rawId = map['id'];
    return Store(
      id: rawId?.toString(),
      name: map['name'] ?? '이름 없음',
      folderName: map['folder_name'] ?? 'default_folder',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'folder_name': folderName,
    };
  }
}