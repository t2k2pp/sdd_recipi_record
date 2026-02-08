class UnitDefinition {
  UnitDefinition({
    required this.id,
    required this.name,
    required this.usesNumber,
  });

  final String id;
  final String name;
  final bool usesNumber;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'usesNumber': usesNumber,
      };

  factory UnitDefinition.fromMap(Map<String, dynamic> map) => UnitDefinition(
        id: (map['id'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        usesNumber: map['usesNumber'] as bool? ?? true,
      );
}
