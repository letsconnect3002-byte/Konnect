import 'dart:convert';

class ProfileFieldFilter {
  /// Parses field assignments JSON or Map into a normalized Map.
  static Map<String, dynamic>? parseFieldAssignments(dynamic faRaw) {
    if (faRaw == null) return null;
    try {
      if (faRaw is String) {
        return jsonDecode(faRaw) as Map<String, dynamic>;
      } else if (faRaw is Map) {
        return Map<String, dynamic>.from(faRaw);
      }
    } catch (_) {}
    return null;
  }

  /// Normalizes non-canonical keys to canonical ones.
  static String normalizeKey(String key) {
    if (key == 'professionalEmail') {
      return 'email';
    } else if (key == 'professionalPhoneNumber') {
      return 'phoneNumber';
    } else if (key == 'professionalBio') {
      return 'bio';
    }
    return key;
  }

  /// In the unified model, fields are visible unless explicitly marked private ('pr' == true).
  /// sharedCard parameter is kept for signature compatibility but ignored.
  static bool isFieldVisible(
    String fieldKey, [
    dynamic sharedCardOrAssignments,
    dynamic fieldAssignments,
  ]) {
    // Name and avatarUrl are always visible
    if (fieldKey == 'name' || fieldKey == 'avatarUrl') return true;

    final dynamic assignmentsRaw = fieldAssignments ??
        (sharedCardOrAssignments is! String ? sharedCardOrAssignments : null);
    final assignments = parseFieldAssignments(assignmentsRaw);

    dynamic assignmentRaw;
    if (assignments != null) {
      assignmentRaw = assignments[fieldKey];
      if (assignmentRaw == null && fieldKey == 'professionalEmail') {
        assignmentRaw = assignments['email'];
      } else if (assignmentRaw == null &&
          fieldKey == 'professionalPhoneNumber') {
        assignmentRaw = assignments['phoneNumber'];
      }
    }

    if (assignmentRaw is Map) {
      if (assignmentRaw['pr'] == true) return false;
    }

    return true;
  }

  /// Returns the filtered value (the raw value if visible, or an empty string if not).
  static String getVisibleValue(
    String fieldKey,
    String rawValue, [
    dynamic sharedCardOrAssignments,
    dynamic fieldAssignments,
  ]) {
    final bool visible =
        isFieldVisible(fieldKey, sharedCardOrAssignments, fieldAssignments);
    return visible ? rawValue : '';
  }
}
