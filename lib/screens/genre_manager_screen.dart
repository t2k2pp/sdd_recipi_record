import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/app_repository.dart';
import '../data/app_storage.dart';
import '../models/genre.dart';

class GenreManagerScreen extends StatelessWidget {
  const GenreManagerScreen({super.key});

  Future<void> _showEditDialog(
    BuildContext context, {
    Genre? genre,
  }) async {
    final controller = TextEditingController(text: genre?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(genre == null ? 'ジャンル追加' : 'ジャンル編集'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'ジャンル名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    if (genre == null) {
      await AppRepository.addGenre(result);
    } else {
      await AppRepository.updateGenre(
        Genre(id: genre.id, name: result, createdAt: genre.createdAt),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, Genre genre) async {
    if (genre.id == AppRepository.uncategorizedId()) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ジャンルを削除しますか？'),
        content: const Text('削除したジャンルは未分類に移動されます。'),
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
    if (confirmed == true) {
      await AppRepository.deleteGenre(genre.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ジャンル管理'),
      ),
      body: ValueListenableBuilder(
        valueListenable: AppStorage.genresBox().listenable(),
        builder: (context, box, child) {
          final genres = AppRepository.getGenres();
          return ListView.separated(
            itemCount: genres.length,
            itemBuilder: (context, index) {
              final genre = genres[index];
              final isDefault =
                  genre.id == AppRepository.uncategorizedId();
              return ListTile(
                title: Text(genre.name),
                subtitle: isDefault ? const Text('削除不可') : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _showEditDialog(context, genre: genre),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: isDefault
                          ? null
                          : () => _confirmDelete(context, genre),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            },
            separatorBuilder: (context, index) => const Divider(height: 1),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('ジャンル追加'),
      ),
    );
  }
}
