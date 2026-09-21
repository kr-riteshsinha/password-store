import 'dart:io';
import 'dart:typed_data';

/// Writes [bytes] to [path] so that a crash or a full disk can never leave a
/// half-written file behind.
///
/// Write to a temporary file, flush it to disk, then rename it over the
/// target — rename is atomic on every filesystem the app supports. A failure
/// leaves either the old file or the new one, never a mixture of the two.
Future<void> writeFileAtomically(String path, Uint8List bytes) async {
  final temp = File('$path.tmp');
  try {
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(path);
  } catch (_) {
    if (await temp.exists()) {
      try {
        await temp.delete();
      } catch (_) {
        // Nothing useful to do: the original file is still intact, which is
        // what matters.
      }
    }
    rethrow;
  }
}

/// Replaces [path] with [source], atomically, keeping no copy behind.
Future<void> replaceFileAtomically(String path, String source) async {
  await File(source).rename(path);
}
