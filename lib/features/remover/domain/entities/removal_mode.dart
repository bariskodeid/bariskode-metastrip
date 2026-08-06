/// Metadata removal strategies.
///
/// MVP only implements [supportedCleanup]; the others are reserved for future
/// phases and must not be promised in copy until implemented.
enum RemovalMode {
  /// Clean supported JPEG/PNG metadata and basic PDF DocInfo fields.
  supportedCleanup,

  /// Remove only user-identifying fields.
  selective,

  /// Anonymize GPS, author, and device-identifying fields.
  anonymize,

  /// Preserve technical metadata (codec, dimensions) while stripping user data.
  preserveTechnical,
}
