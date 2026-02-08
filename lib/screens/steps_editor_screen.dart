import 'package:flutter/material.dart';

import '../models/recipe.dart';

class StepsEditorScreen extends StatefulWidget {
  const StepsEditorScreen({
    super.key,
    required this.initialText,
    required this.format,
  });

  final String initialText;
  final StepsFormat format;

  @override
  State<StepsEditorScreen> createState() => _StepsEditorScreenState();
}

class _StepsEditorScreenState extends State<StepsEditorScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _insertText(String prefix, String suffix) {
    final selection = _controller.selection;
    final text = _controller.text;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final selected = text.substring(start, end);
    final replacement = '$prefix$selected$suffix';
    _controller.text = text.replaceRange(start, end, replacement);
    final cursor = start + prefix.length + selected.length;
    _controller.selection = TextSelection.collapsed(offset: cursor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('手順エディタ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                expands: true,
                maxLines: null,
                minLines: null,
                decoration: const InputDecoration(
                  hintText: '手順を入力してください',
                  border: OutlineInputBorder(),
                ),
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          _ToolButton(
            label: '見出し1',
            icon: Icons.title,
            onTap: () => _insertText('# ', ''),
          ),
          _ToolButton(
            label: '見出し2',
            icon: Icons.title,
            onTap: () => _insertText('## ', ''),
          ),
          _ToolButton(
            label: '太字',
            icon: Icons.format_bold,
            onTap: () => _insertText('**', '**'),
          ),
          _ToolButton(
            label: '斜体',
            icon: Icons.format_italic,
            onTap: () => _insertText('*', '*'),
          ),
          _ToolButton(
            label: '箇条書き',
            icon: Icons.format_list_bulleted,
            onTap: () => _insertText('- ', ''),
          ),
          _ToolButton(
            label: '番号リスト',
            icon: Icons.format_list_numbered,
            onTap: () => _insertText('1. ', ''),
          ),
          _ToolButton(
            label: 'チェック',
            icon: Icons.check_box_outlined,
            onTap: () => _insertText('- [ ] ', ''),
          ),
          _ToolButton(
            label: '引用',
            icon: Icons.format_quote,
            onTap: () => _insertText('> ', ''),
          ),
          _ToolButton(
            label: 'リンク',
            icon: Icons.link,
            onTap: () => _insertText('[', '](https://)'),
          ),
          _ToolButton(
            label: 'インデント',
            icon: Icons.format_indent_increase,
            onTap: () => _indentSelection(),
          ),
          _ToolButton(
            label: '解除',
            icon: Icons.format_indent_decrease,
            onTap: () => _outdentSelection(),
          ),
          if (widget.format == StepsFormat.marp)
            _ToolButton(
              label: '改ページ',
              icon: Icons.view_carousel,
              onTap: () => _insertText('\n---\n', ''),
            ),
        ],
      ),
    );
  }

  void _indentSelection() {
    _transformSelectedLines((line) => line.isEmpty ? line : '  $line');
  }

  void _outdentSelection() {
    _transformSelectedLines((line) {
      if (line.startsWith('  ')) {
        return line.substring(2);
      }
      if (line.startsWith('\t')) {
        return line.substring(1);
      }
      return line;
    });
  }

  void _transformSelectedLines(String Function(String line) transform) {
    final selection = _controller.selection;
    final text = _controller.text;
    final start = selection.start < 0 ? 0 : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final before = text.substring(0, start);
    final selected = text.substring(start, end);
    final after = text.substring(end);
    final lines = selected.split('\n').map(transform).toList();
    final replaced = lines.join('\n');
    _controller.text = before + replaced + after;
    _controller.selection = TextSelection(
      baseOffset: start,
      extentOffset: start + replaced.length,
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        height: 36,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}
