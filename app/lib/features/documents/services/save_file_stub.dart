import 'dart:typed_data';

/// Native (Android/iOS/desktop): writing to app-visible storage needs a
/// platform-specific "downloads" location and permission handling this
/// phase's Flutter work doesn't cover (the app has only been verified on
/// web — see app/README.md). Throwing rather than silently no-op-ing so a
/// native build surfaces this gap immediately instead of pretending the
/// download succeeded.
void saveFile(Uint8List bytes, String filename, String contentType) {
  throw UnsupportedError(
    'Saving downloaded files to disk on this platform is not implemented yet.',
  );
}
