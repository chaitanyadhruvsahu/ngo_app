/// Cross-platform "save these downloaded bytes somewhere the user can get
/// to them" — conditional-import seam (standard Flutter pattern) since the
/// actual mechanism differs entirely between web (a Blob + synthetic
/// anchor click) and native (write to the filesystem), and referencing
/// `dart:html` directly would fail to compile for the Android target this
/// app also ships (see app/README.md, ADR-0001).
library;

export 'save_file_stub.dart' if (dart.library.html) 'save_file_web.dart';
