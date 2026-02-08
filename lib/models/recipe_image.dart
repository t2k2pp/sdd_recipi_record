class RecipeImage {
  RecipeImage({
    required this.id,
    required this.path,
    required this.caption,
  });

  final String id;
  final String path;
  final String caption;

  Map<String, dynamic> toMap() => {
        'id': id,
        'path': path,
        'caption': caption,
      };

  factory RecipeImage.fromMap(Map<String, dynamic> map) => RecipeImage(
        id: (map['id'] ?? '').toString(),
        path: (map['path'] ?? '').toString(),
        caption: (map['caption'] ?? '').toString(),
      );
}
