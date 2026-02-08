import 'package:hive_flutter/hive_flutter.dart';

class AppStorage {
  static const recipesBoxName = 'recipes';
  static const logsBoxName = 'logs';
  static const genresBoxName = 'genres';
  static const settingsBoxName = 'settings';
  static const unitsBoxName = 'units';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(recipesBoxName);
    await Hive.openBox<Map>(logsBoxName);
    await Hive.openBox<Map>(genresBoxName);
    await Hive.openBox<Map>(settingsBoxName);
    await Hive.openBox<Map>(unitsBoxName);
  }

  static Box<Map> recipesBox() => Hive.box<Map>(recipesBoxName);
  static Box<Map> logsBox() => Hive.box<Map>(logsBoxName);
  static Box<Map> genresBox() => Hive.box<Map>(genresBoxName);
  static Box<Map> settingsBox() => Hive.box<Map>(settingsBoxName);
  static Box<Map> unitsBox() => Hive.box<Map>(unitsBoxName);
}
