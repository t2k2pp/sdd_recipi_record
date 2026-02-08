import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../data/app_repository.dart';
import '../data/app_storage.dart';
import '../models/app_settings.dart';
import '../models/cooking_log.dart';
import '../models/genre.dart';
import '../models/recipe.dart';
import '../services/export_service.dart';
import '../services/image_service.dart';
import '../services/import_service.dart';
import 'genre_manager_screen.dart';
import 'unit_manager_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _importing = false;
  final TextEditingController _defaultServingsController =
      TextEditingController();

  @override
  void dispose() {
    _defaultServingsController.dispose();
    super.dispose();
  }

  Future<void> _updateSettings(AppSettings settings) async {
    await AppRepository.saveSettings(settings);
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('全データ削除'),
        content: const Text('すべてのレシピとログを削除します。元に戻せません。'),
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
    if (confirmed != true) return;
    final baseDir = await ImageService.baseDir();
    await AppRepository.deleteAllData(imagesDir: baseDir);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('全データを削除しました')),
      );
    }
  }

  Future<void> _importZip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _importing = true;
    });
    try {
      final zipFile = File(result.files.single.path!);
      final payload = await ImportService.loadZip(zipFile);
      final data = payload.data;
      final recipeMap = Map<String, dynamic>.from(data['recipe'] as Map);
      final logsMap = (data['logs'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final genreName = data['genreName']?.toString() ?? '未分類';

      final existingRecipes = AppRepository.getRecipes();
      final existingGenres = AppRepository.getGenres();
      var existingUnits = AppRepository.getUnits();

      final existingHash = _findDuplicateHash(payload.hash, existingRecipes);
      if (existingHash != null) {
        _showSnackBar('同じ内容のレシピがすでに登録されています');
        return;
      }

      final nameConflict = existingRecipes
          .firstWhere((r) => r.name == recipeMap['name'], orElse: () => Recipe(
                id: '',
                name: '',
                genreId: '',
                baseServings: 0,
                ingredients: [],
                steps: '',
                stepsFormat: StepsFormat.markdown,
                coverImagePath: null,
                images: [],
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ));

      String? action;
      if (nameConflict.id.isNotEmpty) {
        action = await _showConflictDialog(nameConflict.name);
        if (action == 'cancel') return;
      }

      final genreId = await _resolveGenreId(genreName, existingGenres);
      final baseDir = await ImageService.baseDir();

      final coverPath = recipeMap['coverImagePath']?.toString();
      if (coverPath != null && coverPath.isNotEmpty) {
        final bytes = payload.files['images/$coverPath'];
        if (bytes != null) {
          final newPath = await _writeImageFile(baseDir, coverPath, bytes);
          recipeMap['coverImagePath'] = newPath;
        } else {
          recipeMap['coverImagePath'] = null;
        }
      }

      for (final imageMap in recipeMap['images'] as List? ?? []) {
        final map = imageMap as Map;
        final oldPath = map['path']?.toString();
        if (oldPath == null) continue;
        final bytes = payload.files['images/$oldPath'];
        if (bytes == null) continue;
        final newPath = await _writeImageFile(baseDir, oldPath, bytes);
        map['path'] = newPath;
        map['id'] = const Uuid().v4();
      }

      for (final ingredientMap in recipeMap['ingredients'] as List? ?? []) {
        final map = Map<String, dynamic>.from(ingredientMap as Map);
        final unitName = map['unit']?.toString().trim() ?? '';
        if (unitName.isEmpty) continue;
        final exists = existingUnits.any((unit) => unit.name == unitName);
        if (!exists) {
          final usesNumber = map['quantity'] != null;
          final created = await AppRepository.addUnit(unitName, usesNumber);
          existingUnits = [...existingUnits, created];
        }
      }

      for (final logMap in logsMap) {
        final oldPath = logMap['photoPath']?.toString();
        if (oldPath == null) continue;
        final bytes = payload.files['images/$oldPath'];
        if (bytes == null) continue;
        final newPath = await _writeImageFile(baseDir, oldPath, bytes);
        logMap['photoPath'] = newPath;
      }

      final importedRecipe = Recipe.fromMap(recipeMap).copyWithGenre(genreId);

      if (action == 'overwrite') {
        final baseDir = await ImageService.baseDir();
        await AppRepository.deleteRecipe(nameConflict.id, imagesDir: baseDir);
        final updatedRecipe = importedRecipe.copyWithId(nameConflict.id);
        await AppRepository.saveRecipe(updatedRecipe);
        for (final logMap in logsMap) {
          final log = CookingLog.fromMap(logMap).copyWithRecipe(updatedRecipe.id);
          await AppRepository.addLog(log);
        }
      } else {
        final newName = action == 'rename'
            ? _buildUniqueName(importedRecipe.name, existingRecipes)
            : importedRecipe.name;
        final newRecipe = importedRecipe.copyWithId(const Uuid().v4()).copyWithName(newName);
        await AppRepository.saveRecipe(newRecipe);
        for (final logMap in logsMap) {
          final log = CookingLog.fromMap(logMap)
              .copyWithId(const Uuid().v4())
              .copyWithRecipe(newRecipe.id);
          await AppRepository.addLog(log);
        }
      }

      _showSnackBar('インポートが完了しました');
    } catch (error) {
      _showSnackBar('インポートに失敗しました: $error');
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
        });
      }
    }
  }

  String? _findDuplicateHash(String hash, List<Recipe> existingRecipes) {
    for (final recipe in existingRecipes) {
      final logs = AppRepository.getLogsForRecipe(recipe.id);
      final genre = AppRepository
          .getGenres()
          .firstWhere((g) => g.id == recipe.genreId, orElse: () => Genre(id: '', name: '未分類', createdAt: DateTime.now()));
      final existingHash = ExportService.computeHash(recipe, logs, genre);
      if (existingHash == hash) {
        return recipe.id;
      }
    }
    return null;
  }

  Future<String> _resolveGenreId(String name, List<Genre> genres) async {
    final existing = genres.firstWhere(
      (g) => g.name == name,
      orElse: () => Genre(id: '', name: '', createdAt: DateTime.now()),
    );
    if (existing.id.isNotEmpty) {
      return existing.id;
    }
    final created = await AppRepository.addGenre(name);
    return created.id;
  }

  Future<String?> _showConflictDialog(String name) async {
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('「$name」が既にあります'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('overwrite'),
            child: const Text('上書きする'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('rename'),
            child: const Text('別名で保存する'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  String _buildUniqueName(String base, List<Recipe> recipes) {
    var index = 1;
    var candidate = '$base($index)';
    final names = recipes.map((e) => e.name).toSet();
    while (names.contains(candidate)) {
      index++;
      candidate = '$base($index)';
    }
    return candidate;
  }

  Future<String> _writeImageFile(
    Directory baseDir,
    String oldPath,
    List<int> bytes,
  ) async {
    final segments = oldPath.split('/');
    final subdir = segments.isNotEmpty ? segments.first : 'images';
    final filename = '${const Uuid().v4()}.png';
    final dir = Directory('${baseDir.path}/$subdir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final newPath = '$subdir/$filename';
    final file = File('${baseDir.path}/$newPath');
    await file.writeAsBytes(bytes, flush: true);
    return newPath;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppStorage.settingsBox().listenable(),
      builder: (context, settingsBox, child) {
        final settings = AppRepository.getSettings();
        if (_defaultServingsController.text !=
            settings.defaultServings.toString()) {
          _defaultServingsController.text =
              settings.defaultServings.toString();
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('設定'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '一般設定',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('調理中の画面消灯を防ぐ'),
                subtitle: const Text('レシピ閲覧中は画面をオンに保ちます'),
                value: settings.keepScreenOn,
                onChanged: (value) =>
                    _updateSettings(settings.copyWith(keepScreenOn: value)),
              ),
              ListTile(
                title: const Text('デフォルト基準人数'),
                subtitle: Text('${settings.defaultServings}人前'),
                trailing: SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _defaultServingsController,
                    keyboardType: TextInputType.number,
                    onSubmitted: (value) {
                      final parsed = int.tryParse(value) ?? 2;
                      _updateSettings(
                          settings.copyWith(defaultServings: parsed));
                    },
                  ),
                ),
              ),
              ListTile(
                title: const Text('外観モード'),
                trailing: DropdownButton<ThemeMode>(
                  value: settings.themeMode,
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('システム'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('ライト'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('ダーク'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    _updateSettings(settings.copyWith(themeMode: value));
                  },
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'データ管理',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('ジャンル編集'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GenreManagerScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                title: const Text('単位編集'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const UnitManagerScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                title: const Text('レシピをインポート'),
                trailing: _importing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined),
                onTap: _importing ? null : _importZip,
              ),
              ListTile(
                title: const Text('全データ削除'),
                textColor: Colors.red,
                iconColor: Colors.red,
                trailing: const Icon(Icons.delete_forever_outlined),
                onTap: _confirmDeleteAll,
              ),
              const SizedBox(height: 20),
              Text(
                'アプリ情報',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '-';
                  return ListTile(
                    title: const Text('バージョン'),
                    subtitle: Text(version),
                  );
                },
              ),
              ListTile(
                title: const Text('ライセンス情報'),
                onTap: () => showLicensePage(context: context),
                trailing: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        );
      },
    );
  }
}

extension RecipeCopy on Recipe {
  Recipe copyWithId(String id) => Recipe(
        id: id,
        name: name,
        genreId: genreId,
        baseServings: baseServings,
        ingredients: ingredients,
        steps: steps,
        stepsFormat: stepsFormat,
        coverImagePath: coverImagePath,
        images: images,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Recipe copyWithName(String newName) => Recipe(
        id: id,
        name: newName,
        genreId: genreId,
        baseServings: baseServings,
        ingredients: ingredients,
        steps: steps,
        stepsFormat: stepsFormat,
        coverImagePath: coverImagePath,
        images: images,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Recipe copyWithGenre(String genreId) => Recipe(
        id: id,
        name: name,
        genreId: genreId,
        baseServings: baseServings,
        ingredients: ingredients,
        steps: steps,
        stepsFormat: stepsFormat,
        coverImagePath: coverImagePath,
        images: images,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

extension LogCopy on CookingLog {
  CookingLog copyWithRecipe(String recipeId) => CookingLog(
        id: id,
        recipeId: recipeId,
        date: date,
        note: note,
        photoPath: photoPath,
      );

  CookingLog copyWithId(String id) => CookingLog(
        id: id,
        recipeId: recipeId,
        date: date,
        note: note,
        photoPath: photoPath,
      );
}
