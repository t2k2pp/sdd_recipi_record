import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../data/app_repository.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_image.dart';
import '../models/unit_definition.dart';
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
  StepsFormat _stepsFormat = StepsFormat.markdown;
  File? _coverImageFile;
  String? _coverImagePath;
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
    _stepsFormat = recipe?.stepsFormat ?? StepsFormat.markdown;
    _coverImagePath = recipe?.coverImagePath;
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

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() {
      _coverImageFile = File(file.path);
    });
  }

  void _removeCoverImage() {
    setState(() {
      _coverImageFile = null;
      _coverImagePath = null;
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
      String? coverImagePath;
      final existingCoverPath = widget.existing?.coverImagePath;
      if (_coverImageFile != null) {
        coverImagePath = await ImageService.saveRecipeImage(_coverImageFile!);
        if (existingCoverPath != null && existingCoverPath != coverImagePath) {
          final file = File('${baseDir.path}/$existingCoverPath');
          if (await file.exists()) {
            await file.delete();
          }
        }
      } else if (_coverImagePath != null) {
        coverImagePath = _coverImagePath;
      } else if (existingCoverPath != null) {
        final file = File('${baseDir.path}/$existingCoverPath');
        if (await file.exists()) {
          await file.delete();
        }
      }

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
        stepsFormat: _stepsFormat,
        coverImagePath: coverImagePath,
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
    final units = AppRepository.getUnits();
    final ingredientSuggestions = AppRepository.getRecipes()
        .expand((recipe) => recipe.ingredients)
        .map((ingredient) => ingredient.name)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
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
            Text(
              '出来上がり写真',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildCoverImageCard(),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _pickCoverImage,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('出来上がり写真を選ぶ'),
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
                  child: _buildIngredientRow(
                    index: index,
                    ingredient: ingredient,
                    units: units,
                    ingredientSuggestions: ingredientSuggestions,
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
            DropdownButtonFormField<StepsFormat>(
              key: ValueKey(_stepsFormat),
              initialValue: _stepsFormat,
              items: const [
                DropdownMenuItem(
                  value: StepsFormat.markdown,
                  child: Text('Markdown形式'),
                ),
                DropdownMenuItem(
                  value: StepsFormat.marp,
                  child: Text('Marp形式'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _stepsFormat = value);
              },
              decoration: const InputDecoration(labelText: '表示形式'),
            ),
            const SizedBox(height: 8),
            if (_stepsFormat == StepsFormat.marp)
              const Text(
                'Marpは「---」でページ区切りします。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
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

  Widget _buildCoverImageCard() {
    if (_coverImageFile != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _coverImageFile!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(
              icon: const Icon(Icons.close),
              color: Colors.black87,
              onPressed: _removeCoverImage,
            ),
          ),
        ],
      );
    }

    if (_coverImagePath != null) {
      return FutureBuilder<File>(
        future: ImageService.resolveRelativePath(_coverImagePath!),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.existsSync()) {
            return _buildCoverPlaceholder();
          }
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  snapshot.data!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  color: Colors.black87,
                  onPressed: _removeCoverImage,
                ),
              ),
            ],
          );
        },
      );
    }

    return _buildCoverPlaceholder();
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: const Center(child: Icon(Icons.photo_outlined)),
    );
  }

  Widget _buildIngredientRow({
    required int index,
    required _IngredientDraft ingredient,
    required List<UnitDefinition> units,
    required List<String> ingredientSuggestions,
  }) {
    final unitNames = units.map((e) => e.name).toSet();
    final currentUnit = ingredient.unitController.text.trim();
    final dropdownUnits = [
      if (currentUnit.isNotEmpty && !unitNames.contains(currentUnit))
        UnitDefinition(id: 'custom', name: currentUnit, usesNumber: true),
      ...units,
    ];

    final selectedUnit = currentUnit.isEmpty ? null : currentUnit;
    final usesNumber = _usesNumberForUnit(selectedUnit, units);

    if (!usesNumber && ingredient.quantityController.text.trim().isNotEmpty) {
      ingredient.quantityController.text = '';
    }

    return Row(
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
          child: Autocomplete<String>(
            initialValue: TextEditingValue(text: ingredient.name),
            optionsBuilder: (textEditingValue) {
              final query = textEditingValue.text.trim();
              if (query.isEmpty) return const Iterable<String>.empty();
              return ingredientSuggestions.where(
                (option) => option.contains(query),
              );
            },
            onSelected: (value) => ingredient.name = value,
            fieldViewBuilder: (context, controller, focusNode, onSubmit) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: '材料名',
                ),
                onChanged: (value) => ingredient.name = value,
              );
            },
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
            enabled: usesNumber,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            key: ValueKey(selectedUnit),
            initialValue: selectedUnit,
            isExpanded: true,
            items: dropdownUnits
                .map(
                  (unit) => DropdownMenuItem(
                    value: unit.name,
                    child: Text(unit.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              ingredient.unitController.text = value ?? '';
              final nextUsesNumber = _usesNumberForUnit(value, units);
              if (!nextUsesNumber) {
                ingredient.quantityController.text = '';
              }
              setState(() {});
            },
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
    );
  }

  bool _usesNumberForUnit(String? unitName, List<UnitDefinition> units) {
    if (unitName == null || unitName.isEmpty) return true;
    final unit = units.firstWhere(
      (u) => u.name == unitName,
      orElse: () => UnitDefinition(id: 'custom', name: unitName, usesNumber: true),
    );
    return unit.usesNumber;
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
      : name = '',
        quantityController = TextEditingController(),
        unitController = TextEditingController();

  _IngredientDraft.fromIngredient(Ingredient ingredient)
      : name = ingredient.name,
        quantityController = TextEditingController(
            text: ingredient.quantity?.toString() ?? ''),
        unitController = TextEditingController(text: ingredient.unit);

  String name;
  final TextEditingController quantityController;
  final TextEditingController unitController;

  Ingredient toIngredient() {
    final quantity = double.tryParse(quantityController.text.trim());
    return Ingredient(
      name: name.trim(),
      quantity: quantity,
      unit: unitController.text.trim(),
    );
  }

  void dispose() {
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
