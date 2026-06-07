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

  /// Returns true if a field is visible based on shared card type and field assignments.
  static bool isFieldVisible(
    String fieldKey,
    String sharedCard, // 'casual', 'professional', or 'both'
    dynamic fieldAssignments,
  ) {
    final String key = normalizeKey(fieldKey);

    // Name and avatarUrl are always visible
    if (key == 'name' || key == 'avatarUrl') return true;

    final assignments = parseFieldAssignments(fieldAssignments);
    if (assignments == null) return true;

    final assignmentRaw = assignments[key];
    if (assignmentRaw == null) return true;

    final Map<String, dynamic> assignment = Map<String, dynamic>.from(assignmentRaw as Map);
    final bool isCasual = assignment['c'] == true;
    final bool isProfessional = assignment['p'] == true;

    final cleanSharedCard = sharedCard.toLowerCase();
    if (cleanSharedCard == 'casual') {
      return isCasual;
    } else if (cleanSharedCard == 'professional') {
      return isProfessional;
    } else {
      return isCasual || isProfessional;
    }
  }

  /// Returns the filtered value (the raw value if visible, or an empty string if not).
  static String getVisibleValue(
    String fieldKey,
    String rawValue,
    String sharedCard,
    dynamic fieldAssignments,
  ) {
    final bool visible = isFieldVisible(fieldKey, sharedCard, fieldAssignments);
    return visible ? rawValue : '';
  }
}
