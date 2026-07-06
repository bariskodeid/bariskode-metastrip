import 'package:flutter/material.dart';
import 'package:metastrip/core/theme/app_spacing.dart';
import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
import 'package:path/path.dart' as p;

/// Shows batch stats and per-file outcomes after processing completes.
class ResultScreen extends StatelessWidget {
  const ResultScreen({required this.results, super.key});

  final List<ProcessingResultEntity> results;

  @override
  Widget build(BuildContext context) {
    final success = results.where((r) => r.success).length;
    final failure = results.length - success;
    final totalBytes =
        results.fold(0, (sum, r) => sum + r.bytesWritten);

    return Scaffold(
      appBar: AppBar(title: const Text('RESULTS')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 2.2,
              children: [
                _StatTile(
                  label: 'STRIPPED',
                  value: '$success',
                  color: Colors.green,
                ),
                _StatTile(
                  label: 'FAILED',
                  value: '$failure',
                  color: failure == 0 ? Colors.grey : Colors.red,
                ),
                _StatTile(
                  label: 'TOTAL',
                  value: '${results.length}',
                  color: Colors.blue,
                ),
                _StatTile(
                  label: 'BYTES WRITTEN',
                  value: _formatBytes(totalBytes),
                  color: Colors.amber,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('OUTPUT FILES', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('No files were processed.'))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final result = results[index];
                        return ListTile(
                          leading: Icon(
                            result.success
                                ? Icons.check_circle
                                : Icons.error,
                            color: result.success ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          title: Text(
                            p.basename(result.inputPath),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            result.success
                                ? p.basename(result.outputPath!)
                                : result.error ?? 'Unknown error',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: () => Navigator.of(context)
                  .popUntil((route) => route.isFirst),
              icon: const Icon(Icons.check),
              label: const Text('DONE'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
