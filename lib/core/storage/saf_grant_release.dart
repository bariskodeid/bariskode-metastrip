import 'package:saf/saf.dart';

/// Releases a persisted Storage Access Framework grant for a tree URI.
typedef SafGrantReleaser = Future<void> Function(String uri);

/// Default [SafGrantReleaser] backed by the `saf` plugin.
Future<void> releaseSafGrant(String uri) =>
    Saf().releasePersistedPermission(uri);

/// Best-effort release of the grant behind [oldFolder].
///
/// Does nothing unless [oldFolder] is a `content://` URI that differs from
/// [newFolder]. Any error from [release] is swallowed so that releasing a
/// stale grant can never block a folder change.
Future<void> releaseReplacedSafGrant(
  String? oldFolder,
  String? newFolder,
  SafGrantReleaser release,
) async {
  if (oldFolder == null ||
      !oldFolder.startsWith('content://') ||
      oldFolder == newFolder) {
    return;
  }
  try {
    await release(oldFolder);
  } catch (_) {
    // Best effort only.
  }
}
