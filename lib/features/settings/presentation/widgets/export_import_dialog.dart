import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:metastrip/shared/widgets/secondary_button.dart';
import 'package:saf/saf.dart';

/// Signature of the import file picker (defaults to `openFile`).
typedef OpenFileFn = Future<XFile?> Function({
  List<XTypeGroup> acceptedTypeGroups,
});

/// Accepted type group for settings import; declares the iOS UTI and MIME.
const XTypeGroup settingsJsonTypeGroup = XTypeGroup(
  label: 'JSON',
  extensions: ['json'],
  uniformTypeIdentifiers: ['public.json'],
  mimeTypes: ['application/json'],
);

/// Dialog for exporting/importing settings JSON.
///
/// Export writes `metastrip-settings-<yyyyMMdd-HHmmss>.json` into
/// [outputFolder]: through SAF for `content://` folders, otherwise as a plain
/// file.
class ExportImportDialog extends StatelessWidget {
  const ExportImportDialog({
    super.key,
    required this.onExport,
    required this.onImport,
    this.outputFolder,
    this.clock = DateTime.now,
    this.openFileFn = openFile,
  });

  final Future<bool> Function(String) onExport;
  final Future<bool> Function(String) onImport;

  /// Configured output folder (local path or `content://` tree URI).
  final String? outputFolder;

  /// Time source used for the export file name.
  final DateTime Function() clock;

  /// Import file picker; injectable for tests.
  final OpenFileFn openFileFn;

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// Builds the export file name for [time].
  static String exportFileName(DateTime time) =>
      'metastrip-settings-${time.year.toString().padLeft(4, '0')}'
      '${_two(time.month)}${_two(time.day)}-'
      '${_two(time.hour)}${_two(time.minute)}${_two(time.second)}.json';

  /// Exports to the output folder and returns the saved file name.
  Future<String?> _export() async {
    final folder = outputFolder?.trim();
    if (folder == null || folder.isEmpty) return null;
    final name = exportFileName(clock());
    if (folder.startsWith('content://')) {
      final temp = await Directory.systemTemp.createTemp('metastrip_export');
      try {
        final tempFile = File('${temp.path}/$name');
        if (!await onExport(tempFile.path)) return null;
        final document = await Saf().writeFileBytes(
          folder,
          name,
          'application/json',
          await tempFile.readAsBytes(),
        );
        return document.name;
      } finally {
        await temp.delete(recursive: true);
      }
    }
    final target = '$folder${Platform.pathSeparator}$name';
    return await onExport(target) ? name : null;
  }

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
              final messenger = ScaffoldMessenger.of(context);
              String message;
              try {
                final saved = await _export();
                message = saved == null ? 'Export failed' : 'Saved $saved';
              } catch (_) {
                message = 'Export failed';
              }
              messenger.showSnackBar(SnackBar(content: Text(message)));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Import Settings'),
            subtitle: const Text('Load settings from a JSON file'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                final file = await openFileFn(
                  acceptedTypeGroups: const [settingsJsonTypeGroup],
                );
                if (file == null) return;
                if (await onImport(file.path)) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Settings imported')),
                  );
                }
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Import failed')),
                );
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
