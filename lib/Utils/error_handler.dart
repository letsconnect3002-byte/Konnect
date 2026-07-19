String getFriendlyErrorMessage(dynamic e) {
  if (e == null) return "An unexpected error occurred. Please try again.";
  final message = e.toString().toLowerCase();

  // Network/Connection errors
  if (message.contains('network') ||
      message.contains('socketexception') ||
      message.contains('connection refused') ||
      message.contains('failed host lookup') ||
      message.contains('timeout') ||
      message.contains('xmlhttprequest') ||
      message.contains('failed to connect')) {
    return "Network error. Please check your internet connection and try again.";
  }

  // Supabase/Auth/DB unique constraint errors
  if (message.contains('unique_constraint') ||
      message.contains('already exists') ||
      message.contains('duplicate key')) {
    return "This record already exists.";
  }

  // Supabase Auth specific error parsing
  if (message.contains('invalid login credentials') ||
      message.contains('invalid_credentials')) {
    return "Incorrect email or password. Please try again.";
  }
  if (message.contains('email not confirmed') ||
      message.contains('email_not_confirmed')) {
    return "Please verify your email address before signing in.";
  }
  if (message.contains('user not found') ||
      message.contains('user_not_found')) {
    return "No account found with this email.";
  }
  if (message.contains('user already exists') ||
      message.contains('email already in use') ||
      message.contains('email_already_exists')) {
    return "An account with this email address already exists.";
  }
  if (message.contains('weak password') ||
      message.contains('password_too_short')) {
    return "Please choose a stronger password (at least 6 characters).";
  }
  if (message.contains('invalid verification code') ||
      message.contains('invalid_grant') ||
      message.contains('otp_expired') ||
      message.contains('invalid token')) {
    return "Invalid or expired verification code. Please request a new one.";
  }

  // Permission/RLS issues
  if (message.contains('row-level security') ||
      message.contains('violates row-level security policy') ||
      message.contains('permission denied')) {
    return "You do not have permission to perform this action.";
  }

  // Storage / Upload issues
  if (message.contains('bucket not found') ||
      message.contains('storage') ||
      message.contains('upload')) {
    return "Failed to upload image. Please try again.";
  }

  // Return clean text if it's already friendly
  if (e is Exception) {
    final cleanStr = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    if (cleanStr.length > 5 &&
        cleanStr.length < 100 &&
        !cleanStr.contains('Exception') &&
        !cleanStr.contains('PostgrestException')) {
      return cleanStr;
    }
  }

  return "Something went wrong. Please try again.";
}
