import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:metastrip/shared/widgets/secondary_button.dart';

/// Dialog for exporting/importing settings JSON.
class ExportImportDialog extends StatelessWidget {
  const ExportImportDialog({
    super.key,
    required this.onExport,
    required this.onImport,
  });

  final Future<bool> Function(String) onExport;
  final Future<bool> Function(String) onImport;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export / Import Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Export Settings'),
            subtitle: const Text('Save current settings to a JSON file'),
            onTap: () async {
              final location = await getSaveLocation(
                suggestedName: 'metastrip-settings.json',
                acceptedTypeGroups: const [
                  XTypeGroup(label: 'JSON', extensions: ['json']),
                ],
              );
              if (location != null && context.mounted) {
                final succeeded = await onExport(location.path);
                if (succeeded && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings exported')),
                  );
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Import Settings'),
            subtitle: const Text('Load settings from a JSON file'),
            onTap: () async {
              final file = await openFile(
                acceptedTypeGroups: const [
                  XTypeGroup(label: 'JSON', extensions: ['json']),
                ],
              );
              if (file != null && context.mounted) {
                final succeeded = await onImport(file.path);
                if (succeeded && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings imported')),
                  );
                }
              }
            },
          ),
        ],
      ),
      actions: [
        SecondaryButton(
          label: 'CLOSE',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
