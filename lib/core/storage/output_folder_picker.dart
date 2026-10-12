import 'dart:io' show Directory;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saf/saf.dart';

/// Opens a folder picker and returns the chosen output folder, or `null`.
///
/// Failures are reported through `onError`; callers show them to the user.
typedef DirectoryPicker = Future<String?> Function({
  void Function(Object error)? onError,
});

/// Picks an output folder with a mobile-safe system picker.
///
/// On Android this opens the Storage Access Framework tree picker and asks
/// for a persistable read+write grant, so the remover can write to the
/// returned `content://` tree URI in later sessions. Any failure is caught,
/// reported through [onError], and returned as `null`; a cancelled pick also
/// returns `null` without calling [onError].
///
/// On iOS there is no folder picker; the output folder is
/// `<app Documents>/MetaStrip`, created on demand. It is visible in the Files
/// app under On My iPhone because the Info.plist enables file sharing.
///
/// Other platforms are not supported yet: [onError] receives an
/// [UnsupportedError] and the result is `null`.
Future<String?> pickOutputFolder({void Function(Object error)? onError}) async {
  try {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final directory = await Saf().pickDirectory(
        writePermission: true,
        persistablePermission: true,
      );
      return directory?.uri;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final documents = await getApplicationDocumentsDirectory();
      final folder = Directory('${documents.path}/MetaStrip');
      await folder.create(recursive: true);
      return folder.path;
    }
    throw UnsupportedError(
      'Output folder selection is not supported on this platform.',
    );
  } catch (error) {
    onError?.call(error);
    return null;
  }
}
