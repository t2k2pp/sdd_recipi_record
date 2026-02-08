import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/app_repository.dart';
import '../data/app_storage.dart';
import '../models/recipe.dart';
import '../services/image_service.dart';
import 'recipe_detail_screen.dart';
import 'recipe_editor_screen.dart';
import 'settings_screen.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _genreFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<ImageProvider?> _buildImage(String? relativePath) async {
    if (relativePath == null) {
      return null;
    }
    final file = await ImageService.resolveRelativePath(relativePath);
    if (!await file.exists()) {
      return null;
    }
    return FileImage(file);
  }

  void _openEditor([Recipe? recipe]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeEditorScreen(existing: recipe),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppStorage.settingsBox().listenable(),
      builder: (context, settingsBox, child) {
        final settings = AppRepository.getSettings();
        return ValueListenableBuilder(
          valueListenable: AppStorage.genresBox().listenable(),
          builder: (context, genresBox, child) {
            final genres = AppRepository.getGenres();
            return ValueListenableBuilder(
              valueListenable: AppStorage.recipesBox().listenable(),
              builder: (context, recipesBox, child) {
                final recipes = AppRepository.getRecipes();
                final searchText = _searchController.text.trim().toLowerCase();
                final filtered = recipes.where((recipe) {
                  final matchesSearch = searchText.isEmpty ||
                      recipe.name.toLowerCase().contains(searchText);
                  final matchesGenre = _genreFilter == 'all' ||
                      recipe.genreId == _genreFilter;
                  return matchesSearch && matchesGenre;
                }).toList();
                filtered.sort((a, b) => settings.sortAscending
                    ? a.name.compareTo(b.name)
                    : b.name.compareTo(a.name));

                return Scaffold(
                  appBar: AppBar(
                    title: const Text('レシピ一覧'),
                    actions: [
                      IconButton(
                        onPressed: () async {
                          final updated = settings.copyWith(
                            galleryMode: !settings.galleryMode,
                          );
                          await AppRepository.saveSettings(updated);
                        },
                        icon: Icon(
                          settings.galleryMode
                              ? Icons.view_list_outlined
                              : Icons.grid_view_outlined,
                        ),
                        tooltip: settings.galleryMode ? 'リスト表示' : 'ギャラリー表示',
                      ),
                      IconButton(
                        onPressed: () async {
                          final updated = settings.copyWith(
                            sortAscending: !settings.sortAscending,
                          );
                          await AppRepository.saveSettings(updated);
                        },
                        icon: Icon(settings.sortAscending
                            ? Icons.sort_by_alpha
                            : Icons.sort_by_alpha_outlined),
                        tooltip:
                            settings.sortAscending ? '名前 昇順' : '名前 降順',
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                  body: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                labelText: '料理名で検索',
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              key: ValueKey(_genreFilter),
                              initialValue: _genreFilter,
                              items: [
                                const DropdownMenuItem(
                                  value: 'all',
                                  child: Text('すべてのジャンル'),
                                ),
                                ...genres
                                    .map(
                                      (genre) => DropdownMenuItem(
                                        value: genre.id,
                                        child: Text(genre.name),
                                      ),
                                    ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _genreFilter = value;
                                });
                              },
                              decoration: const InputDecoration(
                                labelText: 'ジャンルフィルタ',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text('まだレシピがありません'),
                              )
                            : settings.galleryMode
                                ? GridView.builder(
                                    padding: const EdgeInsets.all(12),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.9,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final recipe = filtered[index];
                                      final genre = genres.firstWhere(
                                        (g) => g.id == recipe.genreId,
                                        orElse: () => genres.first,
                                      );
                                      final imagePath =
                                          recipe.images.isNotEmpty
                                              ? recipe.images.first.path
                                              : null;
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  RecipeDetailScreen(recipeId: recipe.id),
                                            ),
                                          );
                                        },
                                        child: Card(
                                          clipBehavior: Clip.antiAlias,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Expanded(
                                                child: FutureBuilder<ImageProvider?>(
                                                  future: _buildImage(imagePath),
                                                  builder: (context, snapshot) {
                                                    if (snapshot.data == null) {
                                                      return Container(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                        child: const Icon(
                                                          Icons.restaurant_menu,
                                                          size: 48,
                                                        ),
                                                      );
                                                    }
                                                    return Ink.image(
                                                      image: snapshot.data!,
                                                      fit: BoxFit.cover,
                                                    );
                                                  },
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(8),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      recipe.name,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      genre.name,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(12),
                                    itemBuilder: (context, index) {
                                      final recipe = filtered[index];
                                      final genre = genres.firstWhere(
                                        (g) => g.id == recipe.genreId,
                                        orElse: () => genres.first,
                                      );
                                      final imagePath =
                                          recipe.images.isNotEmpty
                                              ? recipe.images.first.path
                                              : null;
                                      return ListTile(
                                        leading: FutureBuilder<ImageProvider?>(
                                          future: _buildImage(imagePath),
                                          builder: (context, snapshot) {
                                            if (snapshot.data == null) {
                                              return const CircleAvatar(
                                                child: Icon(Icons.restaurant_menu),
                                              );
                                            }
                                            return CircleAvatar(
                                              backgroundImage: snapshot.data,
                                            );
                                          },
                                        ),
                                        title: Text(recipe.name),
                                        subtitle: Text(genre.name),
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  RecipeDetailScreen(recipeId: recipe.id),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    separatorBuilder: (context, index) =>
                                        const Divider(height: 1),
                                    itemCount: filtered.length,
                                  ),
                      ),
                    ],
                  ),
                  floatingActionButton: FloatingActionButton.extended(
                    onPressed: () => _openEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('新規レシピ'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
