import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metastrip/core/constants/supported_extensions.dart';
import 'package:metastrip/core/storage/output_folder_repository.dart';
import 'package:metastrip/core/theme/app_spacing.dart';
import 'package:metastrip/features/remover/domain/repositories/remover_repository.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_bloc.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_event.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_state.dart';
import 'package:metastrip/features/remover/presentation/screens/processing_screen.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';

/// Queue screen for the Remover. Receives marked files from the Viewer,
/// shows supported/unsupported status, and launches [ProcessingScreen].
///
/// Acts as the composition root for the remover feature: constructs the
/// repository implementation and injects it into the BLoC so the BLoC only
/// depends on the domain interface.
class RemoverScreen extends StatelessWidget {
  const RemoverScreen({
    required this.initialFiles,
    required this.outputFolderRepository,
    required this.removerRepository,
    super.key,
  });

  final List<FileItemEntity> initialFiles;
  final OutputFolderRepository outputFolderRepository;
  final RemoverRepository removerRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RemoverBloc(
        repository: removerRepository,
        outputFolderRepository: outputFolderRepository,
      )..add(RemoverFilesAdded(initialFiles)),
      child: const _RemoverView(),
    );
  }
}

class _RemoverView extends StatelessWidget {
  const _RemoverView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RemoverBloc, RemoverState>(
      builder: (context, state) {
        final bloc = context.read<RemoverBloc>();
        final supported = state.files
            .where((f) => RemoverStrippableExtensions.contains(f.extension))
            .length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('REMOVER'),
            actions: [
              if (state.files.isNotEmpty)
                IconButton(
                  tooltip: 'Clear queue',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () => bloc.add(const RemoverClearRequested()),
                ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.files.length} FILE(S) QUEUED · '
                  '$supported SUPPORTED FOR CLEANUP',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'JPEG/PNG METADATA CLEANUP · PDF DOCINFO (BEST EFFORT)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: state.files.isEmpty
                      ? Center(
                          child: Text(
                            'No files queued. Mark files in the Viewer and '
                            'send them here.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          itemCount: state.files.length,
                          itemBuilder: (context, index) {
                            final file = state.files[index];
                            final isStrippable =
                                RemoverStrippableExtensions.contains(
                                    file.extension);
                            return ListTile(
                              leading: Icon(
                                isStrippable ? Icons.check_circle : Icons.block,
                                color:
                                    isStrippable ? Colors.green : Colors.grey,
                                size: 20,
                              ),
                              title: Text(file.name),
                              subtitle: Text(
                                _supportDescription(file.extension),
                              ),
                              trailing: IconButton(
                                tooltip: 'Remove from queue',
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () => bloc.add(
                                  RemoverFileRemoved(file.path),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: FilledButton.icon(
                onPressed: supported == 0
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BlocProvider.value(
                              value: context.read<RemoverBloc>(),
                              child: const ProcessingScreen(),
                            ),
                          ),
                        ),
                icon: const Icon(Icons.cleaning_services_outlined),
                label: Text('CLEAN $supported FILE(S)'),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _supportDescription(String extension) {
  if (!RemoverStrippableExtensions.contains(extension)) {
    return 'Unsupported by remover MVP';
  }
  if (extension == 'pdf') {
    return 'PDF basic DocInfo cleanup only (best effort)';
  }
  return '${extension.toUpperCase()} supported metadata cleanup';
}
