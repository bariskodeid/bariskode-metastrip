/// File extensions accepted by the Viewer MVP.
class SupportedExtensions {
  SupportedExtensions._();

  static const values = <String>[
    // Images
    'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'tiff', 'tif', 'heic',
    // Video
    'mp4', 'mov', 'avi', 'mkv', 'webm', '3gp', 'flv', 'wmv',
    // Audio
    'mp3', 'flac', 'aac', 'ogg', 'wav', 'm4a', 'opus', 'wma', 'aiff',
    'aif', 'aifc',
    // Documents
    'pdf', 'docx', 'xlsx', 'pptx', 'odt', 'ods', 'odp', 'rtf', 'txt',
    // Archives
    'zip', 'tar', 'apk', 'epub',
  ];

  static const _lookup = <String>{
    ...values,
  };

  static bool contains(String extension) => _lookup.contains(extension);
}

/// Extensions the Remover MVP can actually strip.
///
/// This is the single source of truth — consumed by both the datasource
/// format switch and the queue UI gate. Audio, image and office formats are
/// covered; video and archive formats are intentionally excluded.
class RemoverStrippableExtensions {
  RemoverStrippableExtensions._();

  static const values = <String>{
    'jpg', 'jpeg', 'png', 'pdf',
    'mp3', 'flac', 'ogg', 'opus', 'wav', 'aiff',
    'docx', 'xlsx', 'pptx', 'odt', 'ods', 'odp',
    'gif', 'webp',
  };

  static bool contains(String extension) =>
      values.contains(extension.toLowerCase());
}
