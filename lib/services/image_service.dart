import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageService {
  static final _uuid = const Uuid();

  static Future<Directory> _baseDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final base = Directory(path.join(docDir.path, 'images'));
    if (!await base.exists()) {
      await base.create(recursive: true);
    }
    return base;
  }

  static Future<Directory> recipeDir() async {
    final base = await _baseDir();
    final dir = Directory(path.join(base.path, 'recipes'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> logDir() async {
    final base = await _baseDir();
    final dir = Directory(path.join(base.path, 'logs'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> saveRecipeImage(File file) async {
    final dir = await recipeDir();
    return _resizeAndSave(file, dir, 'recipes');
  }

  static Future<String> saveLogImage(File file) async {
    final dir = await logDir();
    return _resizeAndSave(file, dir, 'logs');
  }

  static Future<String> _resizeAndSave(
    File file,
    Directory targetDir,
    String subdirName,
  ) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('画像の読み込みに失敗しました');
    }
    final resized = img.copyResize(
      decoded,
      width: 640,
      height: 480,
      interpolation: img.Interpolation.average,
    );
    final filename = '${_uuid.v4()}.png';
    final outPath = path.join(targetDir.path, filename);
    final outFile = File(outPath);
    await outFile.writeAsBytes(img.encodePng(resized));
    return path.join(subdirName, filename);
  }

  static Future<File> resolveRelativePath(String relativePath) async {
    final base = await _baseDir();
    return File(path.join(base.path, relativePath));
  }

  static Future<Directory> baseDir() => _baseDir();
}
