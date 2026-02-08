import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/app_repository.dart';
import '../data/app_storage.dart';
import '../models/unit_definition.dart';

class UnitManagerScreen extends StatelessWidget {
  const UnitManagerScreen({super.key});

  Future<void> _showEditDialog(
    BuildContext context, {
    UnitDefinition? unit,
  }) async {
    final nameController = TextEditingController(text: unit?.name ?? '');
    var usesNumber = unit?.usesNumber ?? true;

    final result = await showDialog<_UnitDialogResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(unit == null ? '単位追加' : '単位編集'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '単位名'),
            ),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (context, setState) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('数値を入力する単位'),
                subtitle: const Text('例: g, ml, 個 など'),
                value: usesNumber,
                onChanged: (value) => setState(() => usesNumber = value),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              _UnitDialogResult(
                name: nameController.text.trim(),
                usesNumber: usesNumber,
              ),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == null || result.name.isEmpty) return;
    if (unit == null) {
      await AppRepository.addUnit(result.name, result.usesNumber);
    } else {
      await AppRepository.updateUnit(
        UnitDefinition(
          id: unit.id,
          name: result.name,
          usesNumber: result.usesNumber,
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, UnitDefinition unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('単位を削除しますか？'),
        content: const Text('レシピに使われている単位名は保持されます。'),
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
      await AppRepository.deleteUnit(unit.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('単位管理'),
      ),
      body: ValueListenableBuilder(
        valueListenable: AppStorage.unitsBox().listenable(),
        builder: (context, box, child) {
          final units = AppRepository.getUnits();
          return ListView.separated(
            itemCount: units.length,
            itemBuilder: (context, index) {
              final unit = units[index];
              return ListTile(
                title: Text(unit.name),
                subtitle: Text(unit.usesNumber ? '数値入力あり' : '数値入力なし'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _showEditDialog(context, unit: unit),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: () => _confirmDelete(context, unit),
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
        label: const Text('単位追加'),
      ),
    );
  }
}

class _UnitDialogResult {
  _UnitDialogResult({required this.name, required this.usesNumber});

  final String name;
  final bool usesNumber;
}
