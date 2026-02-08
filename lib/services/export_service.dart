import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../models/cooking_log.dart';
import '../models/genre.dart';
import '../models/recipe.dart';
import 'image_service.dart';

class ExportService {
  static String computeHash(Recipe recipe, List<CookingLog> logs, Genre? genre) {
    final exportMap = {
      'schemaVersion': 1,
      'recipe': recipe.toMap(),
      'logs': logs.map((e) => e.toMap()).toList(),
      'genreName': genre?.name ?? '未分類',
    };
    final canonical = jsonEncode(exportMap);
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static Future<File?> exportRecipe(
    Recipe recipe,
    List<CookingLog> logs,
    Genre? genre,
    File? targetFile,
  ) async {
    if (targetFile == null) {
      return null;
    }

    final exportMap = {
      'schemaVersion': 1,
      'recipe': recipe.toMap(),
      'logs': logs.map((e) => e.toMap()).toList(),
      'genreName': genre?.name ?? '未分類',
    };
    final hash = computeHash(recipe, logs, genre);
    final payload = {
      'hash': hash,
      'data': exportMap,
    };

    final archive = Archive();
    final jsonBytes = utf8.encode(jsonEncode(payload));
    archive.addFile(ArchiveFile('recipe.json', jsonBytes.length, jsonBytes));

    final baseDir = await ImageService.baseDir();

    if (recipe.coverImagePath != null) {
      final file = File(path.join(baseDir.path, recipe.coverImagePath!));
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final zipPath = path.join('images', recipe.coverImagePath!);
        archive.addFile(ArchiveFile(zipPath, bytes.length, bytes));
      }
    }

    for (final image in recipe.images) {
      final file = File(path.join(baseDir.path, image.path));
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final zipPath = path.join('images', image.path);
        archive.addFile(ArchiveFile(zipPath, bytes.length, bytes));
      }
    }

    for (final log in logs) {
      if (log.photoPath == null) continue;
      final file = File(path.join(baseDir.path, log.photoPath!));
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final zipPath = path.join('images', log.photoPath!);
        archive.addFile(ArchiveFile(zipPath, bytes.length, bytes));
      }
    }

    final zipData = ZipEncoder().encode(archive);
    await targetFile.writeAsBytes(zipData);
    return targetFile;
  }
}
