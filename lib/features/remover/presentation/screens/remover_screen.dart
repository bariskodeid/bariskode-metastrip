import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metastrip/core/format/format_registry.dart';
import 'package:metastrip/core/storage/output_folder_repository.dart';
import 'package:metastrip/core/theme/app_spacing.dart';
import 'package:metastrip/core/utils/file_utils.dart';
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
    this.pickFiles = _pickRemoverFiles,
    super.key,
  });

  final List<FileItemEntity> initialFiles;
  final OutputFolderRepository outputFolderRepository;
  final RemoverRepository removerRepository;
  final Future<List<PlatformFile>?> Function() pickFiles;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RemoverBloc(
        repository: removerRepository,
        outputFolderRepository: outputFolderRepository,
        validateInputs: true,
      )..add(RemoverFilesAdded(initialFiles)),
      child: _RemoverView(pickFiles: pickFiles),
    );
  }
}

class _RemoverView extends StatelessWidget {
  const _RemoverView({required this.pickFiles});

  final Future<List<PlatformFile>?> Function() pickFiles;

  @override
  Widget build(BuildContext context) {
    return BlocListener<RemoverBloc, RemoverState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage &&
          current.errorMessage != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.errorMessage!)),
        );
      },
      child: BlocBuilder<RemoverBloc, RemoverState>(
        builder: (context, state) {
          final bloc = context.read<RemoverBloc>();
          final supported = state.files
              .where(
                  (f) => FormatRegistry.standard.supportsRemoval(f.extension))
              .length;

          return Scaffold(
            appBar: AppBar(
              title: const Text('REMOVER'),
              actions: [
                IconButton(
                  tooltip: 'Add files',
                  icon: const Icon(Icons.add),
                  onPressed: () => _selectFiles(context),
                ),
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
                    'AUDIO · IMAGE · OFFICE · PDF METADATA CLEANUP',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: state.files.isEmpty
                        ? Center(
                            child: FilledButton.icon(
                              onPressed: () => _selectFiles(context),
                              icon: const Icon(Icons.add),
                              label: const Text('ADD FILES'),
                            ),
                          )
                        : ListView.builder(
                            itemCount: state.files.length,
                            itemBuilder: (context, index) {
                              final file = state.files[index];
                              final isStrippable = FormatRegistry.standard
                                  .supportsRemoval(file.extension);
                              return ListTile(
                                leading: Icon(
                                  isStrippable
                                      ? Icons.check_circle
                                      : Icons.block,
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
      ),
    );
  }

  Future<void> _selectFiles(BuildContext context) async {
    try {
      final selected = await pickFiles();
      if (selected == null || !context.mounted) return;
      context.read<RemoverBloc>().add(
            RemoverFilesAdded(
              selected
                  .where((file) => file.path != null)
                  .map(
                    (file) => FileItemEntity(
                      path: file.path!,
                      name: FileUtils.fileName(file.path!),
                      extension: FileUtils.extension(file.path!),
                      sizeBytes: file.size,
                      addedAt: DateTime.now(),
                    ),
                  )
                  .toList(),
            ),
          );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to pick files. Check permissions and retry.'),
        ),
      );
    }
  }
}

Future<List<PlatformFile>?> _pickRemoverFiles() async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: FileType.custom,
    allowedExtensions:
        FormatRegistry.standard.removableExtensions.toList(growable: false),
    withData: false,
  );
  return result?.files;
}

/// Per-format support copy shown under each queued file.
String _supportDescription(String extension) {
  final capability = FormatRegistry.standard.lookup(extension);
  if (capability?.supportsFullRemoval != true) {
    return 'Unsupported by remover';
  }
  return capability!.knownLimitations.firstOrNull ??
      '${extension.toUpperCase()} metadata cleanup supported';
}
