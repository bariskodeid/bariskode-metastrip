import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/core/theme/app_spacing.dart';
import 'package:metastrip/features/viewer/data/datasources/metadata_extractor_datasource.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_entity.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';
import 'package:metastrip/features/viewer/presentation/widgets/extension_badge.dart';

class MetadataDetailScreen extends StatefulWidget {
  const MetadataDetailScreen({required this.file, super.key});

  final FileItemEntity file;

  @override
  State<MetadataDetailScreen> createState() => _MetadataDetailScreenState();
}

class _MetadataDetailScreenState extends State<MetadataDetailScreen> {
  bool _computeHash = false;
  late Future<MetadataEntity> _metadataFuture;

  @override
  void initState() {
    super.initState();
    _metadataFuture = _extractMetadata();
  }

  Future<MetadataEntity> _extractMetadata() {
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

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _HeaderCard(file: widget.file),
              const SizedBox(height: AppSpacing.md),
              ...snapshot.data!.fieldsBySection.entries.map(
                (entry) => _SectionCard(
                  title: entry.key,
                  fields: entry.value,
                ),
              ),
            ],
          );
        },
      ),
    );
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
  const _SectionCard({required this.title, required this.fields});

  final String title;
  final List<MetadataFieldEntity> fields;

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
