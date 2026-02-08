class CookingLog {
  CookingLog({
    required this.id,
    required this.recipeId,
    required this.date,
    required this.note,
    required this.photoPath,
  });

  final String id;
  final String recipeId;
  final DateTime date;
  final String note;
  final String? photoPath;

  Map<String, dynamic> toMap() => {
        'id': id,
        'recipeId': recipeId,
        'date': date.toIso8601String(),
        'note': note,
        'photoPath': photoPath,
      };

  factory CookingLog.fromMap(Map<String, dynamic> map) => CookingLog(
        id: (map['id'] ?? '').toString(),
        recipeId: (map['recipeId'] ?? '').toString(),
        date: DateTime.tryParse((map['date'] ?? '').toString()) ?? DateTime.now(),
        note: (map['note'] ?? '').toString(),
        photoPath: map['photoPath']?.toString(),
      );
}
