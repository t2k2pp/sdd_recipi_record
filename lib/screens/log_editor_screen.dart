import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/app_repository.dart';
import '../models/cooking_log.dart';
import '../models/recipe.dart';
import '../services/image_service.dart';

class LogEditorScreen extends StatefulWidget {
  const LogEditorScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<LogEditorScreen> createState() => _LogEditorScreenState();
}

class _LogEditorScreenState extends State<LogEditorScreen> {
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  File? _photo;
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() {
      _photo = File(file.path);
    });
  }

  Future<void> _save() async {
    if (_noteController.text.trim().isEmpty) {
      _showSnackBar('振り返りコメントを入力してください');
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      String? photoPath;
      if (_photo != null) {
        photoPath = await ImageService.saveLogImage(_photo!);
      }
      final log = CookingLog(
        id: const Uuid().v4(),
        recipeId: widget.recipe.id,
        date: _date,
        note: _noteController.text.trim(),
        photoPath: photoPath,
      );
      await AppRepository.addLog(log);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      _showSnackBar('保存に失敗しました: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('調理ログを追加'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('日付'),
            subtitle: Text(DateFormat('yyyy/MM/dd').format(_date)),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today_outlined),
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (selected == null) return;
                setState(() => _date = selected);
              },
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: '振り返り',
              alignLabelWithHint: true,
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          Text(
            '写真 (任意)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _photo!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Icon(Icons.photo_outlined)),
            ),
          TextButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('写真を選ぶ'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中...' : '保存'),
          ),
        ],
      ),
    );
  }
}
