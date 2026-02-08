class Ingredient {
  Ingredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  final String name;
  final double? quantity;
  final String unit;

  Map<String, dynamic> toMap() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
      };

  factory Ingredient.fromMap(Map<String, dynamic> map) => Ingredient(
        name: (map['name'] ?? '').toString(),
        quantity: map['quantity'] == null
            ? null
            : (map['quantity'] as num).toDouble(),
        unit: (map['unit'] ?? '').toString(),
      );
}
