import 'ingredient.dart';
import 'recipe_image.dart';

class Recipe {
  Recipe({
    required this.id,
    required this.name,
    required this.genreId,
    required this.baseServings,
    required this.ingredients,
    required this.steps,
    required this.images,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String genreId;
  final double baseServings;
  final List<Ingredient> ingredients;
  final String steps;
  final List<RecipeImage> images;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'genreId': genreId,
        'baseServings': baseServings,
        'ingredients': ingredients.map((e) => e.toMap()).toList(),
        'steps': steps,
        'images': images.map((e) => e.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Recipe.fromMap(Map<String, dynamic> map) => Recipe(
        id: (map['id'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        genreId: (map['genreId'] ?? '').toString(),
        baseServings: (map['baseServings'] as num?)?.toDouble() ?? 2,
        ingredients: (map['ingredients'] as List? ?? [])
            .map((e) => Ingredient.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        steps: (map['steps'] ?? '').toString(),
        images: (map['images'] as List? ?? [])
            .map((e) => RecipeImage.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        createdAt: DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
            DateTime.now(),
        updatedAt: DateTime.tryParse((map['updatedAt'] ?? '').toString()) ??
            DateTime.now(),
      );
}
