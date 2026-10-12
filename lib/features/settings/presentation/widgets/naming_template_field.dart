import 'package:flutter/material.dart';

/// Text field for output filename template with placeholder hints.
class NamingTemplateField extends StatefulWidget {
  const NamingTemplateField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.enabled = true,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;

  /// When false the field is read-only and shows "Not yet applied".
  final bool enabled;

  @override
  State<NamingTemplateField> createState() => _NamingTemplateFieldState();
}

class _NamingTemplateFieldState extends State<NamingTemplateField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late String _lastPersistedValue;

  @override
  void initState() {
    super.initState();
    _lastPersistedValue = widget.initialValue;
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(NamingTemplateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && !_focusNode.hasFocus) {
      _lastPersistedValue = widget.initialValue;
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) _persistDraft();
  }

  void _persistDraft() {
    final value = _controller.text;
    if (value == _lastPersistedValue) return;
    _lastPersistedValue = value;
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.drive_file_rename_outline),
      title: const Text('Filename Template'),
      enabled: widget.enabled,
      subtitle: Text(
        widget.enabled
            ? 'Placeholders: {name}, {ext}, {date}, {time}'
            : 'Not yet applied',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: SizedBox(
        width: 180,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _persistDraft(),
        ),
      ),
    );
  }
}
