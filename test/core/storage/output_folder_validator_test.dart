import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/errors/app_exceptions.dart';
import 'package:metastrip/core/storage/output_folder_validator.dart';

void main() {
  test('rejects a missing folder', () async {
    final path = '${Directory.systemTemp.path}/metastrip-missing-folder';

    expect(
      () => validateOutputFolder(path),
      throwsA(isA<OutputFolderException>()),
    );
  });

  test('rejects a file as an output folder', () async {
    final file = File(
      '${Directory.systemTemp.path}/metastrip-output-file-${DateTime.now().microsecondsSinceEpoch}',
    );
    await file.writeAsString('not a directory');
    addTearDown(file.delete);

    expect(
      () => validateOutputFolder(file.path),
      throwsA(isA<OutputFolderException>()),
    );
  });

  test('rejects Android SAF tree URIs on non-Android hosts', () async {
    const uri =
        'content://com.android.externalstorage.documents/tree/primary%3ADownload';

    expect(
      () => validateOutputFolder(uri),
      throwsA(isA<OutputFolderException>()),
    );
  });
}
