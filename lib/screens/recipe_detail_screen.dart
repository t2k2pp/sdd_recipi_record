import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/app_repository.dart';
import '../data/app_storage.dart';
import '../models/cooking_log.dart';
import '../models/recipe.dart';
import '../services/export_service.dart';
import '../services/image_service.dart';
import 'log_editor_screen.dart';
import 'recipe_editor_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late double _servings;

  @override
  void initState() {
    super.initState();
    final recipe = AppRepository.getRecipe(widget.recipeId);
    _servings = recipe?.baseServings ?? 2;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = AppRepository.getSettings();
    if (settings.keepScreenOn) {
      WakelockPlus.enable();
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  String _formatQuantity(double value) {
    final formatted = value.toStringAsFixed(2);
    return formatted.replaceFirst(RegExp(r'\.00$'), '').replaceFirst(RegExp(r'(\.[0-9])0$'), r'$1');
  }

  Future<void> _shareRecipe(Recipe recipe, {required bool ingredientsOnly}) async {
    final buffer = StringBuffer();
    buffer.writeln(recipe.name);
    buffer.writeln('');
    buffer.writeln('材料 (${_formatQuantity(_servings)}人前)');
    for (final ingredient in recipe.ingredients) {
      if (ingredient.quantity == null) {
        buffer.writeln('・${ingredient.name} ${ingredient.unit}');
      } else {
        final scaled = ingredient.quantity! / recipe.baseServings * _servings;
        buffer.writeln(
            '・${ingredient.name} ${_formatQuantity(scaled)}${ingredient.unit}');
      }
    }
    if (!ingredientsOnly) {
      buffer.writeln('');
      buffer.writeln('手順');
      final lines = recipe.steps.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        buffer.writeln('${i + 1}. $line');
      }
    }
    await SharePlus.instance.share(
      ShareParams(text: buffer.toString()),
    );
  }

  Future<void> _exportRecipe(Recipe recipe, List<CookingLog> logs) async {
    final targetPath = await _selectExportPath(recipe.name);
    if (targetPath == null) {
      return;
    }
    final genre = AppRepository.getGenres().firstWhere(
          (g) => g.id == recipe.genreId,
          orElse: () => AppRepository.getGenres().first,
        );
    await ExportService.exportRecipe(recipe, logs, genre, File(targetPath));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zipを保存しました')),
    );
  }

  Future<String?> _selectExportPath(String name) async {
    return FilePicker.platform.saveFile(
      dialogTitle: 'Zipの保存先',
      fileName: '$name.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
  }

  Future<ImageProvider?> _loadImage(String relativePath) async {
    final file = await ImageService.resolveRelativePath(relativePath);
    if (!await file.exists()) {
      return null;
    }
    return FileImage(file);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppStorage.recipesBox().listenable(),
      builder: (context, recipesBox, child) {
        final recipe = AppRepository.getRecipe(widget.recipeId);
        if (recipe == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('レシピ詳細')),
            body: const Center(child: Text('レシピが見つかりませんでした')),
          );
        }
        return ValueListenableBuilder(
          valueListenable: AppStorage.logsBox().listenable(),
          builder: (context, logsBox, child) {
            final logs = AppRepository.getLogsForRecipe(recipe.id);
            logs.sort((a, b) => b.date.compareTo(a.date));
            final genre = AppRepository.getGenres().firstWhere(
              (g) => g.id == recipe.genreId,
              orElse: () => AppRepository.getGenres().first,
            );
            final headerImagePath =
                recipe.images.isNotEmpty ? recipe.images.first.path : null;

            return Scaffold(
              appBar: AppBar(
                title: Text(recipe.name),
                actions: [
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RecipeEditorScreen(existing: recipe),
                            ),
                          );
                          break;
                        case 'delete':
                          final confirmed = await _confirmDelete();
                          if (!confirmed) return;
                          final baseDir = await ImageService.baseDir();
                          await AppRepository.deleteRecipe(
                            recipe.id,
                            imagesDir: baseDir,
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          break;
                        case 'share_ingredients':
                          await _shareRecipe(recipe, ingredientsOnly: true);
                          break;
                        case 'share_full':
                          await _shareRecipe(recipe, ingredientsOnly: false);
                          break;
                        case 'export':
                          await _exportRecipe(recipe, logs);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('編集'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('削除'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'share_ingredients',
                        child: Text('材料だけ共有'),
                      ),
                      const PopupMenuItem(
                        value: 'share_full',
                        child: Text('フルレシピ共有'),
                      ),
                      const PopupMenuItem(
                        value: 'export',
                        child: Text('Zipエクスポート'),
                      ),
                    ],
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (headerImagePath != null)
                    FutureBuilder<ImageProvider?>(
                      future: _loadImage(headerImagePath),
                      builder: (context, snapshot) {
                        if (snapshot.data == null) {
                          return _buildPlaceholder();
                        }
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image(
                            image: snapshot.data!,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    )
                  else
                    _buildPlaceholder(),
                  const SizedBox(height: 12),
                  Text(
                    genre.name,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  _buildServingsController(recipe),
                  const SizedBox(height: 16),
                  Text(
                    '材料',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...recipe.ingredients.map((ingredient) {
                    if (ingredient.quantity == null) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${ingredient.name} ${ingredient.unit}'),
                        subtitle: Text(
                          '基準分量 (${_formatQuantity(recipe.baseServings)}人前) の値',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                      );
                    }
                    final scaled =
                        ingredient.quantity! / recipe.baseServings * _servings;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${ingredient.name} ${_formatQuantity(scaled)}${ingredient.unit}',
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Text(
                    '手順',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ..._buildStepLines(recipe.steps),
                  if (recipe.images.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '参考画像',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: recipe.images.map((image) {
                        return SizedBox(
                          width: 160,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FutureBuilder<ImageProvider?>(
                                future: _loadImage(image.path),
                                builder: (context, snapshot) {
                                  if (snapshot.data == null) {
                                    return Container(
                                      height: 100,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      child: const Icon(Icons.image_not_supported),
                                    );
                                  }
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image(
                                      image: snapshot.data!,
                                      height: 100,
                                      width: 160,
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 6),
                              Text(
                                image.caption.isEmpty
                                    ? '（キャプションなし）'
                                    : image.caption,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '調理ログ',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LogEditorScreen(recipe: recipe),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('追加'),
                      ),
                    ],
                  ),
                  if (logs.isEmpty)
                    const Text('まだログがありません')
                  else
                    ...logs.map(
                      (log) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(DateFormat('yyyy/MM/dd').format(log.date)),
                          subtitle: Text(log.note),
                          trailing: log.photoPath == null
                              ? null
                              : FutureBuilder<ImageProvider?>(
                                  future: _loadImage(log.photoPath!),
                                  builder: (context, snapshot) {
                                    if (snapshot.data == null) {
                                      return const Icon(Icons.photo);
                                    }
                                    return CircleAvatar(
                                      backgroundImage: snapshot.data,
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Icon(Icons.restaurant_menu, size: 48),
      ),
    );
  }

  Widget _buildServingsController(Recipe recipe) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '人数: ${_formatQuantity(_servings)}人前',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _servings = (_servings - 1).clamp(1.0, 99.0);
            });
          },
          icon: const Icon(Icons.remove_circle_outline),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _servings = (_servings + 1).clamp(1.0, 99.0);
            });
          },
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  List<Widget> _buildStepLines(String steps) {
    final lines = steps.split('\n');
    var index = 1;
    return lines
        .where((line) => line.trim().isNotEmpty)
        .map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${index++}. '),
                  Expanded(child: Text(line.trim())),
                ],
              ),
            ))
        .toList();
  }

  Future<bool> _confirmDelete() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除しますか？'),
        content: const Text('レシピと関連データを削除します。元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
