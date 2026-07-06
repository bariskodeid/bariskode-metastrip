import 'dart:io';

import 'package:path/path.dart' as p;

/// Small file/path helpers used before full metadata engine exists.
class FileUtils {
  FileUtils._();

  static String fileName(String path) => p.basename(path);

  static String extension(String path) {
    final extension = p.extension(path).replaceFirst('.', '').trim();
    return extension.isEmpty ? 'file' : extension.toLowerCase();
  }

  static int sizeBytes(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final digits = value >= 10 || unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[unitIndex]}';
  }
}
