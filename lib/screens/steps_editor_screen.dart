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
            label: 'H1',
            icon: Icons.title,
            onTap: () => _insertText('# ', ''),
          ),
          _ToolButton(
            label: 'H2',
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
          if (widget.format == StepsFormat.marp)
            _ToolButton(
              label: '区切り',
              icon: Icons.view_carousel,
              onTap: () => _insertText('\n---\n', ''),
            ),
        ],
      ),
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
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}
