import 'package:flutter/material.dart';

/// Radio group for output folder structure: flat or nested.
class FolderStructureSelector extends StatelessWidget {
  const FolderStructureSelector({
    super.key,
    required this.currentValue,
    required this.onChanged,
    this.enabled = true,
  });

  final String currentValue;
  final ValueChanged<String> onChanged;

  /// When false the options are inert and the tile shows "Not yet applied".
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.account_tree_outlined),
      enabled: enabled,
      title: const Text('Folder Structure'),
      subtitle: RadioGroup<String>(
        groupValue: currentValue,
        onChanged: (value) {
          if (enabled && value != null) onChanged(value);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!enabled) const Text('Not yet applied'),
            RadioListTile<String>(
              value: 'flat',
              enabled: enabled,
              title: const Text('Flat'),
              subtitle: const Text('All files in one folder'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            RadioListTile<String>(
              value: 'nested',
              enabled: enabled,
              title: const Text('Nested'),
              subtitle: const Text('Preserve directory structure'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}
