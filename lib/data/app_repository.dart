import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../models/app_settings.dart';
import '../models/cooking_log.dart';
import '../models/genre.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_image.dart';
import '../models/unit_definition.dart';
import 'app_storage.dart';

class AppRepository {
  static const _settingsKey = 'app';
  static const _uncategorizedId = 'uncategorized';
  static final _uuid = const Uuid();

  static Future<void> ensureDefaults() async {
    final settingsBox = AppStorage.settingsBox();
    if (!settingsBox.containsKey(_settingsKey)) {
      await settingsBox.put(_settingsKey, AppSettings.defaults().toMap());
    }

    final genresBox = AppStorage.genresBox();
    if (genresBox.isEmpty) {
      final now = DateTime.now();
      final defaults = <Genre>[
        Genre(id: _uncategorizedId, name: '未分類', createdAt: now),
        Genre(id: _uuid.v4(), name: '日本食', createdAt: now),
        Genre(id: _uuid.v4(), name: '中華', createdAt: now),
        Genre(id: _uuid.v4(), name: 'イタリアン', createdAt: now),
        Genre(id: _uuid.v4(), name: 'フレンチ', createdAt: now),
      ];
      for (final genre in defaults) {
        await genresBox.put(genre.id, genre.toMap());
      }
    }

    final unitsBox = AppStorage.unitsBox();
    if (unitsBox.isEmpty) {
      final defaults = <UnitDefinition>[
        UnitDefinition(id: _uuid.v4(), name: 'g', usesNumber: true),
        UnitDefinition(id: _uuid.v4(), name: 'ml', usesNumber: true),
        UnitDefinition(id: _uuid.v4(), name: 'cc', usesNumber: true),
        UnitDefinition(id: _uuid.v4(), name: '大さじ', usesNumber: true),
        UnitDefinition(id: _uuid.v4(), name: '小さじ', usesNumber: true),
        UnitDefinition(id: _uuid.v4(), name: '個', usesNumber: true),
        UnitDefinition(id: _uuid.v4(), name: '片', usesNumber: true),
        UnitDefinition(id: _uuid.v4(), name: '少々', usesNumber: false),
        UnitDefinition(id: _uuid.v4(), name: '適量', usesNumber: false),
        UnitDefinition(id: _uuid.v4(), name: 'お好み', usesNumber: false),
      ];
      for (final unit in defaults) {
        await unitsBox.put(unit.id, unit.toMap());
      }
    }
  }

  static AppSettings getSettings() {
    final map = AppStorage.settingsBox().get(_settingsKey);
    return AppSettings.fromMap(map == null ? null : Map<String, dynamic>.from(map));
  }

  static Future<void> saveSettings(AppSettings settings) async {
    await AppStorage.settingsBox().put(_settingsKey, settings.toMap());
  }

  static List<Genre> getGenres() {
    return AppStorage.genresBox()
        .values
        .map((e) => Genre.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static List<UnitDefinition> getUnits() {
    return AppStorage.unitsBox()
        .values
        .map((e) => UnitDefinition.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<UnitDefinition> addUnit(String name, bool usesNumber) async {
    final unit = UnitDefinition(
      id: _uuid.v4(),
      name: name,
      usesNumber: usesNumber,
    );
    await AppStorage.unitsBox().put(unit.id, unit.toMap());
    return unit;
  }

  static Future<void> updateUnit(UnitDefinition unit) async {
    await AppStorage.unitsBox().put(unit.id, unit.toMap());
  }

  static Future<void> deleteUnit(String unitId) async {
    await AppStorage.unitsBox().delete(unitId);
  }

  static Future<Genre> addGenre(String name) async {
    final genre = Genre(id: _uuid.v4(), name: name, createdAt: DateTime.now());
    await AppStorage.genresBox().put(genre.id, genre.toMap());
    return genre;
  }

  static Future<void> updateGenre(Genre genre) async {
    await AppStorage.genresBox().put(genre.id, genre.toMap());
  }

  static Future<void> deleteGenre(String genreId) async {
    if (genreId == _uncategorizedId) {
      return;
    }
    final recipes = getRecipes();
    for (final recipe in recipes) {
      if (recipe.genreId == genreId) {
        final updated = Recipe(
          id: recipe.id,
          name: recipe.name,
          genreId: _uncategorizedId,
          baseServings: recipe.baseServings,
          ingredients: recipe.ingredients,
          steps: recipe.steps,
          stepsFormat: recipe.stepsFormat,
          coverImagePath: recipe.coverImagePath,
          images: recipe.images,
          createdAt: recipe.createdAt,
          updatedAt: DateTime.now(),
        );
        await saveRecipe(updated);
      }
    }
    await AppStorage.genresBox().delete(genreId);
  }

  static List<Recipe> getRecipes() {
    return AppStorage.recipesBox()
        .values
        .map((e) => Recipe.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Recipe? getRecipe(String id) {
    final map = AppStorage.recipesBox().get(id);
    if (map == null) {
      return null;
    }
    return Recipe.fromMap(Map<String, dynamic>.from(map));
  }

  static Future<Recipe> saveRecipe(Recipe recipe) async {
    await AppStorage.recipesBox().put(recipe.id, recipe.toMap());
    return recipe;
  }

  static Future<Recipe> createRecipe({
    required String name,
    required String genreId,
    required double baseServings,
    required List<Ingredient> ingredients,
    required String steps,
    required StepsFormat stepsFormat,
    required String? coverImagePath,
    required List<RecipeImage> images,
  }) async {
    final now = DateTime.now();
    final recipe = Recipe(
      id: _uuid.v4(),
      name: name,
      genreId: genreId,
      baseServings: baseServings,
      ingredients: ingredients,
      steps: steps,
      stepsFormat: stepsFormat,
      coverImagePath: coverImagePath,
      images: images,
      createdAt: now,
      updatedAt: now,
    );
    await saveRecipe(recipe);
    return recipe;
  }

  static Future<void> deleteRecipe(String id, {required Directory imagesDir}) async {
    final recipe = getRecipe(id);
    if (recipe != null) {
      if (recipe.coverImagePath != null) {
        final file = File(path.join(imagesDir.path, recipe.coverImagePath!));
        if (await file.exists()) {
          await file.delete();
        }
      }
      for (final image in recipe.images) {
        final file = File(path.join(imagesDir.path, image.path));
        if (await file.exists()) {
          await file.delete();
        }
      }
      final logs = getLogsForRecipe(id);
      for (final log in logs) {
        if (log.photoPath != null) {
          final file = File(path.join(imagesDir.path, log.photoPath!));
          if (await file.exists()) {
            await file.delete();
          }
        }
        await AppStorage.logsBox().delete(log.id);
      }
    }
    await AppStorage.recipesBox().delete(id);
  }

  static List<CookingLog> getLogsForRecipe(String recipeId) {
    return AppStorage.logsBox()
        .values
        .map((e) => CookingLog.fromMap(Map<String, dynamic>.from(e)))
        .where((log) => log.recipeId == recipeId)
        .toList();
  }

  static Future<CookingLog> addLog(CookingLog log) async {
    await AppStorage.logsBox().put(log.id, log.toMap());
    return log;
  }

  static Future<void> deleteLog(String logId) async {
    await AppStorage.logsBox().delete(logId);
  }

  static Future<void> deleteAllData({required Directory imagesDir}) async {
    final recipes = getRecipes();
    for (final recipe in recipes) {
      if (recipe.coverImagePath != null) {
        final file = File(path.join(imagesDir.path, recipe.coverImagePath!));
        if (await file.exists()) {
          await file.delete();
        }
      }
      for (final image in recipe.images) {
        final file = File(path.join(imagesDir.path, image.path));
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
    final logs = AppStorage.logsBox()
        .values
        .map((e) => CookingLog.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    for (final log in logs) {
      if (log.photoPath != null) {
        final file = File(path.join(imagesDir.path, log.photoPath!));
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
    await AppStorage.recipesBox().clear();
    await AppStorage.logsBox().clear();
    await AppStorage.genresBox().clear();
    await AppStorage.settingsBox().clear();
    await AppStorage.unitsBox().clear();
    await ensureDefaults();
  }

  static String uncategorizedId() => _uncategorizedId;
}
