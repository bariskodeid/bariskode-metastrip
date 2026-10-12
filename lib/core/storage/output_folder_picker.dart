import 'dart:io' show Platform;

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
/// Other platforms are not supported yet: [onError] receives an
/// [UnsupportedError] and the result is `null`.
Future<String?> pickOutputFolder({void Function(Object error)? onError}) async {
  try {
    if (Platform.isAndroid) {
      final directory = await Saf().pickDirectory(
        writePermission: true,
        persistablePermission: true,
      );
      return directory?.uri;
    }
    throw UnsupportedError(
      'Output folder selection is not supported on this platform.',
    );
  } catch (error) {
    onError?.call(error);
    return null;
  }
}
