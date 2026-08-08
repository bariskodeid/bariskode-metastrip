import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/storage/output_folder_repository.dart';
import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';
import 'package:metastrip/features/remover/data/repositories/remover_repository_impl.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_bloc.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_event.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_state.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';

void main() {
  test('real remover flow creates a clean copy and preserves the original',
      () async {
    final root = await Directory.systemTemp.createTemp('metastrip_flow_');
    addTearDown(() => root.delete(recursive: true));
    final outputDirectory = await Directory('${root.path}/output').create();
    final input = File('${root.path}/photo.jpg');
    final originalBytes = <int>[
      0xFF,
      0xD8,
      0xFF,
      0xE1,
      0x00,
      0x06,
      1,
      2,
      3,
      4,
      0xFF,
      0xE0,
      0x00,
      0x04,
      9,
      9,
      0xFF,
      0xDA,
      0x00,
      0x02,
      0xAA,
      0xBB,
      0xFF,
      0xD9,
    ];
    await input.writeAsBytes(originalBytes);

    final bloc = RemoverBloc(
      repository: RemoverRepositoryImpl(MetadataRemoverDatasource()),
      outputFolderRepository: _OutputFolder(outputDirectory.path),
      validateInputs: true,
    );
    addTearDown(bloc.close);
    bloc.add(
      RemoverFilesAdded([
        FileItemEntity(
          path: input.path,
          name: input.uri.pathSegments.last,
          extension: 'jpg',
          sizeBytes: originalBytes.length,
          addedAt: DateTime(2026),
        ),
      ]),
    );
    await bloc.stream.firstWhere((state) => state.files.isNotEmpty);

    bloc.add(const RemoverProcessingStarted());
    final completed = await bloc.stream.firstWhere(
      (state) => state.status == RemoverStatus.completed,
    );

    expect(completed.results, hasLength(1));
    expect(completed.results.single.success, isTrue);
    expect(await input.readAsBytes(), originalBytes);
    final outputs = outputDirectory.listSync().whereType<File>().toList();
    expect(outputs, hasLength(1));
    expect(outputs.single.path, contains('_clean'));
    expect(await outputs.single.readAsBytes(), isNot(equals(originalBytes)));
  });

  test('real remover flow reports malformed input without creating output',
      () async {
    final root = await Directory.systemTemp.createTemp('metastrip_bad_flow_');
    addTearDown(() => root.delete(recursive: true));
    final outputDirectory = await Directory('${root.path}/output').create();
    final input = File('${root.path}/broken.jpg');
    await input.writeAsBytes([0x00, 0x01, 0x02]);

    final bloc = RemoverBloc(
      repository: RemoverRepositoryImpl(MetadataRemoverDatasource()),
      outputFolderRepository: _OutputFolder(outputDirectory.path),
      validateInputs: true,
    );
    addTearDown(bloc.close);
    bloc.add(
      RemoverFilesAdded([
        FileItemEntity(
          path: input.path,
          name: 'broken.jpg',
          extension: 'jpg',
          sizeBytes: 3,
          addedAt: DateTime(2026),
        ),
      ]),
    );
    await bloc.stream.firstWhere((state) => state.files.isNotEmpty);

    bloc.add(const RemoverProcessingStarted());
    final completed = await bloc.stream.firstWhere(
      (state) => state.status == RemoverStatus.completed,
    );

    expect(completed.results.single.success, isFalse);
    expect(completed.results.single.error, 'File format invalid or corrupt');
    expect(outputDirectory.listSync().whereType<File>(), isEmpty);
  });
}

class _OutputFolder implements OutputFolderRepository {
  const _OutputFolder(this.path);

  final String path;

  @override
  Future<String> getValidOutputFolder() async => path;
}
