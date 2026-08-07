import 'package:flutter/material.dart';

/// Displays cache size with clear action.
class CacheSizeWidget extends StatelessWidget {
  const CacheSizeWidget({
    super.key,
    required this.sizeBytes,
    required this.onClear,
  });

  final int sizeBytes;
  final VoidCallback onClear;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.cleaning_services_outlined),
      title: const Text('Clear Cache'),
      subtitle: Text(
        sizeBytes > 0
            ? 'Current size: ${_formatBytes(sizeBytes)}'
            : 'Cache is empty',
      ),
      trailing: TextButton(
        onPressed: onClear,
        child: const Text('CLEAR'),
      ),
    );
  }
}
