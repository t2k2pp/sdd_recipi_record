import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/app_repository.dart';
import 'data/app_storage.dart';
import 'screens/recipe_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStorage.init();
  await AppRepository.ensureDefaults();
  runApp(const RecipeApp());
}

class RecipeApp extends StatelessWidget {
  const RecipeApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorSchemeSeed: Colors.teal,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(centerTitle: false),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppStorage.settingsBox().listenable(),
      builder: (context, box, child) {
        final settings = AppRepository.getSettings();
        return MaterialApp(
          title: 'レシピ記録',
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: settings.themeMode,
          home: const RecipeListScreen(),
        );
      },
    );
  }
}
