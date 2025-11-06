class Store {
  int? id;
  String name;

  Store({
    this.id,
    required this.name
  });

  factory Store.fromMap(Map<String, dynamic> map) {
    return Store(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name
    };
  }
}