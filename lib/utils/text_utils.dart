/// First letter of a display name for avatar placeholders.
///
/// `name[0]` throws a RangeError on an empty string, which took down whole
/// list screens when one account had no name.
String initialOf(String? name, {String fallback = '?'}) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return fallback;
  return trimmed.substring(0, 1).toUpperCase();
}
