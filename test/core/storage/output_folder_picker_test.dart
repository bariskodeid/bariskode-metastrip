import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/storage/output_folder_picker.dart';

void main() {
  final skip = Platform.isAndroid ? 'Android uses the SAF picker' : null;

  test('non-Android platforms report UnsupportedError and return null',
      () async {
    final errors = <Object>[];

    final result = await pickOutputFolder(onError: errors.add);

    expect(result, isNull);
    expect(errors, hasLength(1));
    expect(errors.single, isA<UnsupportedError>());
  }, skip: skip);

  test('pickOutputFolder never throws without an onError callback', () async {
    expect(await pickOutputFolder(), isNull);
  }, skip: skip);
}
