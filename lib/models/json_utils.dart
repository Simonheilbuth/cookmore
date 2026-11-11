/// Helpers for reading untrusted JSON from external sources.
///
/// Data from the API is never trusted blindly: values are type-checked,
/// trimmed and length-limited before they are used in the app.
library;

/// Returns a trimmed, non-empty string, or null if [value] is not a usable string.
String? readTrimmedString(Object? value, {int maxLength = 10000}) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.length > maxLength ? trimmed.substring(0, maxLength) : trimmed;
}

/// Returns [value] if it is a valid HTTPS URL, otherwise null.
///
/// Only HTTPS links are accepted so the app never loads images or opens
/// links over an unencrypted connection.
String? readHttpsUrl(Object? value) {
  final text = readTrimmedString(value, maxLength: 2048);
  if (text == null) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri.toString();
}
