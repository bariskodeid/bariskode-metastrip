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
/// format switch and the queue UI gate. Deep format support (video/audio/
/// office) is pending and intentionally excluded.
class RemoverStrippableExtensions {
  RemoverStrippableExtensions._();

  static const values = <String>{'jpg', 'jpeg', 'png', 'pdf'};

  static bool contains(String extension) =>
      values.contains(extension.toLowerCase());
}
