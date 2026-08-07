import 'dart:io';

import 'package:metastrip/core/errors/app_exceptions.dart';
import 'package:saf/saf.dart';

/// Validates that a folder exists and is writable.
typedef OutputFolderValidator = Future<String> Function(String path);

/// Verifies that an output path is a directory that accepts new entries.
///
/// Android system pickers return Storage Access Framework tree URIs
/// (`content://...`) for folders. Those cannot be probed with `dart:io`, so
/// on Android the active SAF grant is checked instead.
Future<String> validateOutputFolder(String path) async {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) {
    throw const OutputFolderException('No output folder is configured');
  }

  if (Platform.isAndroid && normalizedPath.startsWith('content://')) {
    return _validateAndroidTreeUri(normalizedPath);
  }

  try {
    final stat = await FileStat.stat(normalizedPath);
    if (stat.type != FileSystemEntityType.directory) {
      throw const OutputFolderException(
        'The configured output folder is unavailable',
      );
    }

    final probe = await Directory(normalizedPath).createTemp(
      '.metastrip-write-probe-',
    );
    await probe.delete();
    return normalizedPath;
  } on OutputFolderException {
    rethrow;
  } on FileSystemException {
    throw const OutputFolderException(
      'The configured output folder is not writable',
    );
  }
}

/// Confirms the Android Storage Access Framework tree grant is still active.
Future<String> _validateAndroidTreeUri(String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'content') {
    throw const OutputFolderException(
      'The configured output folder is invalid',
    );
  }

  final document = await Saf().stat(value);
  if (document == null || !document.isDir) {
    throw const OutputFolderException(
      'The configured output folder is unavailable',
    );
  }
  return value;
}
