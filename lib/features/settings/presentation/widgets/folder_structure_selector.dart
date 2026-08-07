import 'package:flutter/material.dart';

/// Radio group for output folder structure: flat or nested.
class FolderStructureSelector extends StatelessWidget {
  const FolderStructureSelector({
    super.key,
    required this.currentValue,
    required this.onChanged,
  });

  final String currentValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.account_tree_outlined),
      title: const Text('Folder Structure'),
      subtitle: RadioGroup<String>(
        groupValue: currentValue,
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioListTile<String>(
              value: 'flat',
              title: Text('Flat'),
              subtitle: Text('All files in one folder'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            RadioListTile<String>(
              value: 'nested',
              title: Text('Nested'),
              subtitle: Text('Preserve directory structure'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}
