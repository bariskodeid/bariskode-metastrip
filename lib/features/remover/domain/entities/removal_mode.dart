/// Metadata removal strategies.
///
/// MVP only implements [fullStrip]; the others are reserved for future phases
/// and must not be promised in copy until implemented.
enum RemovalMode {
  /// Remove all metadata segments.
  fullStrip,

  /// Remove only user-identifying fields.
  selective,

  /// Anonymize GPS, author, and device-identifying fields.
  anonymize,

  /// Preserve technical metadata (codec, dimensions) while stripping user data.
  preserveTechnical,
}
