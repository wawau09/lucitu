class Store {
  String? id; // Firebase Document ID를 담기 위해 String으로 변경
  String name;
  String folderName; // DB에 저장된 폴더명 (이미지 경로 탐색용)

  Store({
    this.id,
    required this.name,
    required this.folderName,
  });

  // Firestore에서 데이터를 가져올 때
  factory Store.fromMap(String docId, Map<String, dynamic> map) {
    return Store(
      id: docId,
      name: map['name'] ?? '이름 없음',
      folderName: map['folder_name'] ?? 'default_folder',
    );
  }

  // Firestore에 데이터를 저장할 때
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'folder_name': folderName,
    };
  }
}