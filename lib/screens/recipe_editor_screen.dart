import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../data/app_repository.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_image.dart';
import '../services/image_service.dart';

class RecipeEditorScreen extends StatefulWidget {
  const RecipeEditorScreen({super.key, this.existing});

  final Recipe? existing;

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _servingsController = TextEditingController();
  final _stepsController = TextEditingController();
  final _uuid = const Uuid();

  late List<_IngredientDraft> _ingredients;
  late List<_ImageDraft> _images;
  String? _genreId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = AppRepository.getSettings();
    final recipe = widget.existing;
    _nameController.text = recipe?.name ?? '';
    _servingsController.text =
        (recipe?.baseServings ?? settings.defaultServings).toString();
    _stepsController.text = recipe?.steps ?? '';
    _genreId = recipe?.genreId ?? AppRepository.uncategorizedId();
    _ingredients = (recipe?.ingredients ?? [])
        .map((e) => _IngredientDraft.fromIngredient(e))
        .toList();
    if (_ingredients.isEmpty) {
      _ingredients.add(_IngredientDraft());
    }
    _images = (recipe?.images ?? [])
        .map((e) => _ImageDraft.fromExisting(e))
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingsController.dispose();
    _stepsController.dispose();
    for (final ingredient in _ingredients) {
      ingredient.dispose();
    }
    for (final image in _images) {
      image.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isEmpty) return;
    setState(() {
      _images.addAll(
        files.map(
          (file) => _ImageDraft(
            id: _uuid.v4(),
            file: File(file.path),
          ),
        ),
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final baseServings = double.tryParse(_servingsController.text.trim()) ?? 2;
    if (baseServings <= 0) {
      _showSnackBar('基準人数は1以上で入力してください');
      return;
    }
    if (_genreId == null) {
      _showSnackBar('ジャンルを選択してください');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final ingredients = _ingredients
          .map((draft) => draft.toIngredient())
          .where((ingredient) => ingredient.name.trim().isNotEmpty)
          .toList();

      final baseDir = await ImageService.baseDir();
      final existingPaths = widget.existing?.images.map((e) => e.path).toSet() ??
          <String>{};
      final keepPaths = <String>{};
      final images = <RecipeImage>[];

      for (final draft in _images) {
        if (draft.removed) continue;
        if (draft.file != null) {
          final relative = await ImageService.saveRecipeImage(draft.file!);
          images.add(
            RecipeImage(
              id: draft.id ?? _uuid.v4(),
              path: relative,
              caption: draft.captionController.text.trim(),
            ),
          );
        } else if (draft.path != null) {
          keepPaths.add(draft.path!);
          images.add(
            RecipeImage(
              id: draft.id ?? _uuid.v4(),
              path: draft.path!,
              caption: draft.captionController.text.trim(),
            ),
          );
        }
      }

      final removedPaths = existingPaths.difference(keepPaths);
      for (final removed in removedPaths) {
        final file = File('${baseDir.path}/$removed');
        if (await file.exists()) {
          await file.delete();
        }
      }

      final now = DateTime.now();
      final recipe = Recipe(
        id: widget.existing?.id ?? _uuid.v4(),
        name: _nameController.text.trim(),
        genreId: _genreId!,
        baseServings: baseServings,
        ingredients: ingredients,
        steps: _stepsController.text.trim(),
        images: images,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      );

      await AppRepository.saveRecipe(recipe);
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
    final genres = AppRepository.getGenres();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'レシピ登録' : 'レシピ編集'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '料理名',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '料理名は必須です';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_genreId),
              initialValue: _genreId,
              items: genres
                  .map(
                    (genre) => DropdownMenuItem(
                      value: genre.id,
                      child: Text(genre.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _genreId = value),
              decoration: const InputDecoration(
                labelText: 'ジャンル',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _servingsController,
              decoration: const InputDecoration(
                labelText: '基準分量 (何人前)',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '基準分量は必須です';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              '材料',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ingredients.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _ingredients.removeAt(oldIndex);
                  _ingredients.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final ingredient = _ingredients[index];
                return Padding(
                  key: ValueKey(ingredient),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: ingredient.nameController,
                          decoration: const InputDecoration(
                            labelText: '材料名',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: ingredient.quantityController,
                          decoration: const InputDecoration(
                            labelText: '分量',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: ingredient.unitController,
                          decoration: const InputDecoration(
                            labelText: '単位',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _ingredients.length == 1
                            ? null
                            : () {
                                setState(() {
                                  final removed = _ingredients.removeAt(index);
                                  removed.dispose();
                                });
                              },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                );
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _ingredients.add(_IngredientDraft());
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('材料を追加'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '手順',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _stepsController,
              decoration: const InputDecoration(
                labelText: '手順を入力 (行ごとに分けると便利です)',
                alignLabelWithHint: true,
              ),
              maxLines: 6,
            ),
            const SizedBox(height: 16),
            Text(
              '参考画像',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              '画像はVGAサイズにリサイズして保存されます。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _images
                  .asMap()
                  .entries
                  .map(
                    (entry) => _buildImageCard(entry.key, entry.value),
                  )
                  .toList(),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('画像を追加'),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中...' : '保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(int index, _ImageDraft draft) {
    return SizedBox(
      width: 160,
      child: Column(
        children: [
          Stack(
            children: [
              _buildImagePreview(draft),
              Positioned(
                right: 4,
                top: 4,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  color: Colors.black87,
                  onPressed: () {
                    setState(() {
                      draft.removed = true;
                      _images.removeAt(index);
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: draft.captionController,
            decoration: const InputDecoration(
              labelText: 'キャプション',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(_ImageDraft draft) {
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
    if (draft.file != null) {
      return Container(
        height: 100,
        width: 160,
        decoration: decoration.copyWith(
          image: DecorationImage(
            image: FileImage(draft.file!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    if (draft.path != null) {
      return FutureBuilder<File>(
        future: ImageService.resolveRelativePath(draft.path!),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !(snapshot.data!.existsSync())) {
            return Container(
              height: 100,
              width: 160,
              decoration: decoration,
              child: const Icon(Icons.image_outlined),
            );
          }
          return Container(
            height: 100,
            width: 160,
            decoration: decoration.copyWith(
              image: DecorationImage(
                image: FileImage(snapshot.data!),
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      );
    }
    return Container(
      height: 100,
      width: 160,
      decoration: decoration,
      child: const Icon(Icons.image_outlined),
    );
  }
}

class _IngredientDraft {
  _IngredientDraft()
      : nameController = TextEditingController(),
        quantityController = TextEditingController(),
        unitController = TextEditingController();

  _IngredientDraft.fromIngredient(Ingredient ingredient)
      : nameController = TextEditingController(text: ingredient.name),
        quantityController = TextEditingController(
            text: ingredient.quantity?.toString() ?? ''),
        unitController = TextEditingController(text: ingredient.unit);

  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController unitController;

  Ingredient toIngredient() {
    final quantity = double.tryParse(quantityController.text.trim());
    return Ingredient(
      name: nameController.text.trim(),
      quantity: quantity,
      unit: unitController.text.trim(),
    );
  }

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
  }
}

class _ImageDraft {
  _ImageDraft({
    this.id,
    this.file,
  })  : path = null,
        captionController = TextEditingController();

  _ImageDraft.fromExisting(RecipeImage image)
      : id = image.id,
        path = image.path,
        file = null,
        captionController = TextEditingController(text: image.caption);

  final String? id;
  final String? path;
  final File? file;
  bool removed = false;
  final TextEditingController captionController;

  void dispose() {
    captionController.dispose();
  }
}
