import 'package:flutter/material.dart';
import 'package:metastrip/core/theme/app_spacing.dart';
import 'package:metastrip/shared/widgets/primary_button.dart';

/// Output folder display with picker action.
class OutputFolderPickerWidget extends StatelessWidget {
  const OutputFolderPickerWidget({
    super.key,
    required this.currentPath,
    required this.onPick,
  });

  final String currentPath;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_outlined),
          title: const Text('Output Folder'),
          subtitle: Text(
            currentPath.isEmpty ? 'Not set' : currentPath,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onPick,
        ),
        const SizedBox(height: AppSpacing.xs),
        PrimaryButton(
          label: 'Choose Folder',
          icon: Icons.folder_open,
          onPressed: onPick,
        ),
      ],
    );
  }
}