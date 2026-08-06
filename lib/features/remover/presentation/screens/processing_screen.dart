import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metastrip/core/theme/app_spacing.dart';
import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_bloc.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_event.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_state.dart';
import 'package:metastrip/features/remover/presentation/screens/result_screen.dart';

/// Full-screen processing view that streams per-file progress from the
/// [RemoverBloc] and routes to [ResultScreen] on completion.
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  @override
  void initState() {
    super.initState();
    // Defer until after the first frame so BlocProvider is available.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startProcessing());
  }

  Future<void> _startProcessing() async {
    if (!mounted) return;
    context.read<RemoverBloc>().add(const RemoverProcessingStarted());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RemoverBloc, RemoverState>(
      listenWhen: (prev, curr) =>
          (prev.status != curr.status ||
              prev.errorMessage != curr.errorMessage) &&
          (curr.status == RemoverStatus.completed ||
              curr.status == RemoverStatus.cancelled ||
              curr.status == RemoverStatus.failure),
      listener: (context, state) {
        if (state.status == RemoverStatus.completed) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => ResultScreen(results: state.results),
            ),
          );
        } else {
          final messenger = ScaffoldMessenger.maybeOf(context);
          final errorMessage = state.errorMessage;
          Navigator.of(context).pop();
          if (state.status == RemoverStatus.failure && errorMessage != null) {
            messenger?.showSnackBar(SnackBar(content: Text(errorMessage)));
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('PROCESSING'),
            automaticallyImplyLeading: false,
          ),
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProgressCard(state: state),
                const SizedBox(height: AppSpacing.md),
                Text('LOG', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Expanded(child: _ResultLog(results: state.results)),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: state.status == RemoverStatus.processing
                      ? () => context.read<RemoverBloc>().requestCancel()
                      : null,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('CANCEL'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.state});

  final RemoverState state;

  @override
  Widget build(BuildContext context) {
    final progress = state.progress;
    final done = state.results.length;
    final total = progress?.totalFiles ?? state.files.length;
    final current = progress?.currentFile ?? '—';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STRIPPING METADATA',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              total == 0 ? 'Queuing...' : '$done / $total · $current',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: progress?.percentage ?? 0,
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultLog extends StatelessWidget {
  const _ResultLog({required this.results});

  final List<ProcessingResultEntity> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Text(
          'Waiting for first result...',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView.builder(
      reverse: true,
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[results.length - 1 - index];
        final icon = result.success
            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
            : const Icon(Icons.error, color: Colors.red, size: 20);
        return ListTile(
          dense: true,
          leading: icon,
          title: Text(
            result.inputPath.split(RegExp(r'[/\\]')).last,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            result.success
                ? result.outputPath!.split(RegExp(r'[/\\]')).last
                : result.error ?? 'Unknown error',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }
}
