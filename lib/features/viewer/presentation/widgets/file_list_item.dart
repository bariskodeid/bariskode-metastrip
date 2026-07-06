import 'package:flutter/material.dart';
import 'package:metastrip/core/theme/app_spacing.dart';
import 'package:metastrip/core/utils/file_utils.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';
import 'package:metastrip/features/viewer/presentation/widgets/extension_badge.dart';

class FileListItem extends StatelessWidget {
  const FileListItem({
    required this.file,
    required this.onRemove,
    required this.onOpen,
    required this.onToggleMarked,
    super.key,
  });

  final FileItemEntity file;
  final VoidCallback onRemove;
  final VoidCallback onOpen;
  final VoidCallback onToggleMarked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: onOpen,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: file.isMarkedForRemoval,
              onChanged: (_) => onToggleMarked(),
            ),
            ExtensionBadge(extension: file.extension),
          ],
        ),
        title: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(FileUtils.formatBytes(file.sizeBytes)),
        trailing: IconButton(
          tooltip: 'Remove file',
          icon: Icon(Icons.close, color: theme.colorScheme.error),
          onPressed: onRemove,
        ),
      ),
    );
  }
}
