import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/storage/output_folder_repository.dart';
import 'package:metastrip/core/theme/app_spacing.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';
import 'package:metastrip/features/remover/domain/repositories/remover_repository.dart';
import 'package:metastrip/features/remover/presentation/screens/remover_screen.dart';
import 'package:metastrip/features/settings/presentation/screens/settings_screen.dart';
import 'package:metastrip/features/viewer/presentation/cubit/viewer_cubit.dart';
import 'package:metastrip/features/viewer/presentation/cubit/viewer_state.dart';
import 'package:metastrip/features/viewer/presentation/screens/metadata_detail_screen.dart';
import 'package:metastrip/features/viewer/presentation/widgets/empty_viewer_state.dart';
import 'package:metastrip/features/viewer/presentation/widgets/file_list_item.dart';

class ViewerScreen extends StatelessWidget {
  const ViewerScreen({
    required this.outputFolderRepository,
    required this.removerRepository,
    super.key,
  });

  final OutputFolderRepository outputFolderRepository;
  final RemoverRepository removerRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ViewerCubit(),
      child: _ViewerView(
        outputFolderRepository: outputFolderRepository,
        removerRepository: removerRepository,
      ),
    );
  }
}

class _ViewerView extends StatelessWidget {
  const _ViewerView({
    required this.outputFolderRepository,
    required this.removerRepository,
  });

  final OutputFolderRepository outputFolderRepository;
  final RemoverRepository removerRepository;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ViewerCubit, ViewerState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage &&
          current.errorMessage != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.errorMessage!)),
        );
      },
      builder: (context, state) {
        final cubit = context.read<ViewerCubit>();

        return Scaffold(
          appBar: AppBar(
            title: const Text('METASTRIP VIEWER'),
            actions: [
              if (state.files.isNotEmpty)
                IconButton(
                  tooltip: 'Clear files',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: cubit.clear,
                ),
              IconButton(
                tooltip: 'Add files',
                icon: state.isPicking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                onPressed: state.isPicking ? null : cubit.pickFiles,
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
          body: state.files.isEmpty
              ? EmptyViewerState(
                  isPicking: state.isPicking,
                  onPickFiles: cubit.pickFiles,
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${state.visibleFiles.length}/${state.files.length} VISIBLE · ${AppConstants.maxFilesPerSession} MAX',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          DropdownButton<ViewerSortMode>(
                            value: state.sortMode,
                            onChanged: (value) {
                              if (value != null) cubit.setSortMode(value);
                            },
                            items: const [
                              DropdownMenuItem(
                                value: ViewerSortMode.addedNewest,
                                child: Text('Newest'),
                              ),
                              DropdownMenuItem(
                                value: ViewerSortMode.name,
                                child: Text('Name'),
                              ),
                              DropdownMenuItem(
                                value: ViewerSortMode.size,
                                child: Text('Size'),
                              ),
                              DropdownMenuItem(
                                value: ViewerSortMode.type,
                                child: Text('Type'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Filter by name or extension',
                        ),
                        onChanged: cubit.setFilterQuery,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(
                        child: ListView.builder(
                          itemCount: state.visibleFiles.length,
                          itemBuilder: (context, index) {
                            final file = state.visibleFiles[index];
                            return FileListItem(
                              file: file,
                              onToggleMarked: () =>
                                  cubit.toggleMarkedForRemoval(file.path),
                              onOpen: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => MetadataDetailScreen(
                                    file: file,
                                    onSelectiveCleanup: (fieldIds) {
                                      return Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => RemoverScreen(
                                            initialFiles: [file],
                                            initialPoliciesByPath: {
                                              file.path: StripPolicy.selective(
                                                fieldIds: fieldIds,
                                              ),
                                            },
                                            outputFolderRepository:
                                                outputFolderRepository,
                                            removerRepository:
                                                removerRepository,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              onRemove: () => cubit.removeFile(file.path),
                            );
                          },
                        ),
                      ),
                      if (state.files.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: cubit.markAllVisibleForRemoval,
                                icon: const Icon(Icons.select_all),
                                label: const Text('MARK VISIBLE'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: state.markedCount == 0
                                    ? null
                                    : cubit.clearMarkedForRemoval,
                                icon: const Icon(Icons.clear),
                                label: const Text('CLEAR MARKS'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FilledButton.icon(
                          onPressed: state.markedCount == 0
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => RemoverScreen(
                                        initialFiles: state.files
                                            .where(
                                              (file) => file.isMarkedForRemoval,
                                            )
                                            .toList(),
                                        outputFolderRepository:
                                            outputFolderRepository,
                                        removerRepository: removerRepository,
                                      ),
                                    ),
                                  ),
                          icon: const Icon(Icons.cleaning_services_outlined),
                          label: Text('SEND ${state.markedCount} TO REMOVER'),
                        ),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}
