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

  /// Returns true if a field is visible based on shared card type ('casual' or 'professional') and field assignments.
  static bool isFieldVisible(
    String fieldKey,
    String sharedCard, // Strictly 'casual' or 'professional'
    dynamic fieldAssignments,
  ) {
    // Name and avatarUrl are always visible
    if (fieldKey == 'name' || fieldKey == 'avatarUrl') return true;

    final bool isCasualCard = sharedCard.toLowerCase() != 'professional';
    final assignments = parseFieldAssignments(fieldAssignments);

    // Look up assignment: try exact fieldKey first, then fallback
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

    Map<String, dynamic>? assignment;
    if (assignmentRaw != null && assignmentRaw is Map) {
      assignment = Map<String, dynamic>.from(assignmentRaw);
    }

    final bool isPrivate = assignment?['pr'] == true;
    if (isPrivate) return false;

    // Casual Email rule:
    // There are two types of email; the email for casual should show by default.
    if (fieldKey == 'email') {
      if (isCasualCard) {
        // Casual email shows by default on casual card unless marked private
        return true;
      } else {
        // On professional card, show if enabled on professional
        if (assignment != null && assignment.containsKey('p')) {
          return assignment['p'] == true;
        }
        return true;
      }
    }

    // Professional Email rule:
    if (fieldKey == 'professionalEmail') {
      if (isCasualCard) {
        // Professional email does NOT show on casual card
        return false;
      }
      // On professional card, show by default unless private
      if (assignment != null && assignment.containsKey('p')) {
        return assignment['p'] == true;
      }
      return true;
    }

    if (assignment == null) return true;

    final bool isCasual = assignment['c'] == true;
    final bool isProfessional = assignment['p'] == true;

    return isCasualCard ? isCasual : isProfessional;
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
