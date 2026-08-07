import 'package:flutter/material.dart';

/// Two-step confirmation dialog for resetting all app data.
class ResetDataDialog extends StatefulWidget {
  const ResetDataDialog({
    super.key,
    required this.onConfirm,
  });

  final Future<void> Function() onConfirm;

  @override
  State<ResetDataDialog> createState() => _ResetDataDialogState();
}

class _ResetDataDialogState extends State<ResetDataDialog> {
  bool _stepOneConfirmed = false;

  @override
  Widget build(BuildContext context) {
    if (!_stepOneConfirmed) {
      return AlertDialog(
        title: const Text('Reset All Data?'),
        content: const Text(
          'This removes app settings and onboarding configuration, then '
          'returns you to onboarding. User-created clean copies and output '
          'files are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => setState(() => _stepOneConfirmed = true),
            child: const Text('CONTINUE'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('FINAL CONFIRMATION'),
      content: const Text(
        'Reset app settings and onboarding configuration? Clean copies and '
        'output files will remain on your device.',
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _stepOneConfirmed = false),
          child: const Text('GO BACK'),
        ),
        FilledButton.icon(
          onPressed: () async {
            Navigator.pop(context);
            await widget.onConfirm();
          },
          icon: const Icon(Icons.delete_forever),
          label: const Text('RESET EVERYTHING'),
        ),
      ],
    );
  }
}
