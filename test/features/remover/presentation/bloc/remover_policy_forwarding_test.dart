import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/storage/output_folder_repository.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/remover/domain/entities/processing_result_entity.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';
import 'package:metastrip/features/remover/domain/repositories/remover_repository.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_bloc.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_event.dart';
import 'package:metastrip/features/remover/presentation/bloc/remover_state.dart';
import 'package:metastrip/features/viewer/domain/entities/file_item_entity.dart';

void main() {
  test('RemoverBloc forwards each file policy to the repository', () async {
    final repository = _CapturingRepository();
    final bloc = RemoverBloc(
      repository: repository,
      outputFolderRepository: const _OutputFolderRepository(),
      validateInputs: false,
    );
    addTearDown(bloc.close);
    final png = _file('/input/one.png', 'png');
    final pdf = _file('/input/two.pdf', 'pdf');
    final pngPolicy = StripPolicy.selective(
      fieldIds: {MetadataFieldId.pngText('Author')},
    );
    const pdfPolicy = StripPolicy.supportedCleanup();

    bloc.add(
      RemoverFilesAdded(
        [png, pdf],
        policiesByPath: {
          png.path: pngPolicy,
          pdf.path: pdfPolicy,
        },
      ),
    );
    await bloc.stream.firstWhere((state) => state.files.length == 2);

    bloc.add(const RemoverProcessingStarted());
    await bloc.stream.firstWhere(
      (state) => state.status == RemoverStatus.completed,
    );

    expect(repository.policiesByPath[png.path], same(pngPolicy));
    expect(repository.policiesByPath[pdf.path], same(pdfPolicy));
  });
}

class _CapturingRepository implements RemoverRepository {
  final Map<String, StripPolicy> policiesByPath = {};

  @override
  Future<ProcessingResultEntity> stripFile(
    String path, {
    required String outputDirectory,
    required StripPolicy policy,
  }) async {
    policiesByPath[path] = policy;
    return ProcessingResultEntity.success(
      inputPath: path,
      outputPath: '$path.clean',
    );
  }
}

class _OutputFolderRepository implements OutputFolderRepository {
  const _OutputFolderRepository();

  @override
  Future<String> getValidOutputFolder() async => '/output';
}

FileItemEntity _file(String path, String extension) => FileItemEntity(
      path: path,
      name: path.split('/').last,
      extension: extension,
      sizeBytes: 100,
      addedAt: DateTime(2026),
    );
