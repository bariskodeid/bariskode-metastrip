import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/format/format_registry.dart';
import 'package:metastrip/core/theme/app_spacing.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/viewer/data/datasources/metadata_extractor_datasource.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_entity.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';
import 'package:metastrip/features/viewer/presentation/widgets/extension_badge.dart';

typedef MetadataLoader = Future<MetadataEntity> Function(
  FileItemEntity file, {
  required bool computeHash,
});

typedef SelectiveCleanupCallback = Future<void> Function(
  Set<MetadataFieldId> fieldIds,
);

class MetadataDetailScreen extends StatefulWidget {
  const MetadataDetailScreen({
    required this.file,
    this.metadataLoader,
    this.onSelectiveCleanup,
    super.key,
  });

  final FileItemEntity file;
  final MetadataLoader? metadataLoader;
  final SelectiveCleanupCallback? onSelectiveCleanup;

  @override
  State<MetadataDetailScreen> createState() => _MetadataDetailScreenState();
}

class _MetadataDetailScreenState extends State<MetadataDetailScreen> {
  bool _computeHash = false;
  late Future<MetadataEntity> _metadataFuture;
  final Set<MetadataFieldId> _selectedFieldIds = {};
  bool _handoffInProgress = false;

  @override
  void initState() {
    super.initState();
    _metadataFuture = _extractMetadata();
  }

  Future<MetadataEntity> _extractMetadata() {
    final metadataLoader = widget.metadataLoader;
    if (metadataLoader != null) {
      return metadataLoader(
        widget.file,
        computeHash: _computeHash,
      );
    }

    return MetadataExtractorDatasource().extractBasic(
      widget.file,
      computeHash: _computeHash,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('METADATA DETAIL'),
        actions: [
          TextButton.icon(
            onPressed: _computeHash
                ? null
                : () => setState(() {
                      _computeHash = true;
                      _metadataFuture = _extractMetadata();
                    }),
            icon: const Icon(Icons.tag),
            label: const Text('HASH'),
          ),
        ],
      ),
      body: FutureBuilder<MetadataEntity>(
        future: _metadataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Unable to read file metadata.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }

          final canSelect = FormatRegistry.standard
                  .lookup(widget.file.extension)
                  ?.supportsSelectiveRemoval ==
              true;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    _HeaderCard(file: widget.file),
                    const SizedBox(height: AppSpacing.md),
                    ...snapshot.data!.fieldsBySection.entries.map(
                      (entry) => _SectionCard(
                        title: entry.key,
                        fields: entry.value,
                        selectable: canSelect &&
                            entry.key.trim().toUpperCase() != 'RAW METADATA',
                        selectedFieldIds: _selectedFieldIds,
                        onSelectionChanged: (id, selected) {
                          setState(() {
                            if (selected) {
                              _selectedFieldIds.add(id);
                            } else {
                              _selectedFieldIds.remove(id);
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (canSelect && widget.onSelectiveCleanup != null)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            _selectedFieldIds.isEmpty || _handoffInProgress
                                ? null
                                : _startSelectiveCleanup,
                        icon: const Icon(Icons.cleaning_services_outlined),
                        label: Text(
                          'CLEAN ${_selectedFieldIds.length} SELECTED',
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startSelectiveCleanup() async {
    if (_handoffInProgress || _selectedFieldIds.isEmpty) return;
    setState(() => _handoffInProgress = true);
    try {
      await widget.onSelectiveCleanup!(Set.unmodifiable(_selectedFieldIds));
    } finally {
      if (mounted) setState(() => _handoffInProgress = false);
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.file});

  final FileItemEntity file;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            ExtensionBadge(extension: file.extension),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                file.name,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.fields,
    required this.selectable,
    required this.selectedFieldIds,
    required this.onSelectionChanged,
  });

  final String title;
  final List<MetadataFieldEntity> fields;
  final bool selectable;
  final Set<MetadataFieldId> selectedFieldIds;
  final void Function(MetadataFieldId id, bool selected) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(title.toUpperCase(), style: theme.textTheme.titleSmall),
        children: fields
            .map(
              (field) => ListTile(
                dense: true,
                leading: selectable && field.id != null
                    ? Checkbox(
                        value: selectedFieldIds.contains(field.id),
                        onChanged: (value) =>
                            onSelectionChanged(field.id!, value ?? false),
                      )
                    : null,
                title: Text(field.label),
                subtitle: Text(field.value),
                trailing: Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    if (field.isPrivacySensitive)
                      Icon(
                        Icons.warning_amber_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    IconButton(
                      tooltip: 'Copy metadata value',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: _clipboardValue(field.value)),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Metadata copied')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  String _clipboardValue(String value) {
    if (value.length <= AppConstants.maxMetadataFieldChars) return value;
    return value.substring(0, AppConstants.maxMetadataFieldChars);
  }
}
