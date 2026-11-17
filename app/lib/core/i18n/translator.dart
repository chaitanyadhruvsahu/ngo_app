import 'package:easy_localization/easy_localization.dart' as easy_localization;
import 'package:intl/intl.dart';

/// Thin wrapper around the i18n library (ADR-0005) so every call site in
/// the app depends on this function, not directly on `easy_localization`.
/// If the underlying package is ever swapped, only this file changes.
///
/// Keys follow the namespaced convention agreed before any UI copy is
/// written, e.g. `auth.login_button`, `common.loading`.
String t(String key, {Map<String, String>? args}) {
  return easy_localization.tr(key, namedArgs: args);
}

String displayTimestamp(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return '—';
  return DateFormat.yMMMd().add_jm().format(parsed.toLocal());
}
