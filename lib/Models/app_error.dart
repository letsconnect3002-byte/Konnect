class AppError {
  final String message;
  final String? code;
  final DateTime timestamp;
  
  const AppError({required this.message, this.code, required this.timestamp});
  
  factory AppError.from(Object e) {
    final String rawMsg = e.toString().replaceAll('Exception: ', '').trim();
    String userFriendlyMsg = rawMsg;

    // Standardized network/socket errors
    if (rawMsg.contains('SocketException') ||
        rawMsg.contains('NetworkImage') ||
        rawMsg.contains('HttpException') ||
        rawMsg.contains('Connection reset by peer') ||
        rawMsg.contains('failed to connect') ||
        rawMsg.contains('Network error') ||
        rawMsg.contains('ClientException') ||
        rawMsg.contains('SocketFailed') ||
        rawMsg.contains('host lookup') ||
        rawMsg.contains('No address associated with hostname') ||
        rawMsg.contains('HandshakeException') ||
        rawMsg.contains('TimeoutException') ||
        rawMsg.contains('OS Error') ||
        rawMsg.contains('Software caused connection abort') ||
        rawMsg.contains('Connection timed out') ||
        rawMsg.contains('Failed host lookup')) {
      userFriendlyMsg = 'Network connection issue. Please check your internet connection.';
    }
    // Database, SQL, and synchronization errors
    else if (rawMsg.contains('PostgrestException') ||
        rawMsg.contains('DatabaseException') ||
        rawMsg.contains('SQLiteException') ||
        rawMsg.contains('constraint') ||
        rawMsg.contains('violates') ||
        rawMsg.contains('internal server error') ||
        rawMsg.contains('500') ||
        rawMsg.contains('502') ||
        rawMsg.contains('503') ||
        rawMsg.contains('504') ||
        rawMsg.toLowerCase().contains('select') ||
        rawMsg.toLowerCase().contains('insert') ||
        rawMsg.toLowerCase().contains('update') ||
        rawMsg.toLowerCase().contains('delete') ||
        rawMsg.toLowerCase().contains('table') ||
        rawMsg.toLowerCase().contains('column') ||
        rawMsg.toLowerCase().contains('relation') ||
        rawMsg.toLowerCase().contains('row')) {
      userFriendlyMsg = 'Failed to sync data with the server. Please pull to refresh.';
    }
    // Authentication / Session errors
    else if (rawMsg.contains('JWT') ||
        rawMsg.contains('invalid claim') ||
        rawMsg.contains('Invalid login credentials') ||
        rawMsg.contains('AuthException') ||
        rawMsg.contains('TokenExpired') ||
        rawMsg.toLowerCase().contains('unauthorized')) {
      userFriendlyMsg = 'Your session has expired. Please log in again.';
    }
    // Developer coding/null safety errors
    else if (rawMsg.contains('Null check operator used on a null value') ||
        rawMsg.contains('NullCheckError') ||
        rawMsg.contains('Null check') ||
        rawMsg.contains('TypeError') ||
        rawMsg.contains('RangeError') ||
        rawMsg.contains('FormatException') ||
        rawMsg.toLowerCase().contains('assertion')) {
      userFriendlyMsg = 'Something went wrong. Please try again.';
    }

    return AppError(
      message: userFriendlyMsg,
      timestamp: DateTime.now(),
    );
  }
}
