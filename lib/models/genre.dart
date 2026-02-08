class Genre {
  Genre({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Genre.fromMap(Map<String, dynamic> map) => Genre(
        id: (map['id'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        createdAt: DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
            DateTime.now(),
      );
}
