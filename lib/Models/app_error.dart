class AppError {
  final String message;
  final String? code;
  final DateTime timestamp;
  
  const AppError({required this.message, this.code, required this.timestamp});
  
  factory AppError.from(Object e) {
    final String rawMsg = e.toString().replaceAll('Exception: ', '').trim();
    String userFriendlyMsg = rawMsg;

    if (rawMsg.contains('Null check operator used on a null value') ||
        rawMsg.contains('NullCheckError') ||
        rawMsg.contains('Null check')) {
      userFriendlyMsg = 'Something went wrong. Please try again.';
    } else if (rawMsg.contains('SocketException') ||
        rawMsg.contains('NetworkImage') ||
        rawMsg.contains('HttpException') ||
        rawMsg.contains('Connection reset by peer') ||
        rawMsg.contains('failed to connect') ||
        rawMsg.contains('Network error')) {
      userFriendlyMsg = 'Network connection issue. Please check your internet connection.';
    } else if (rawMsg.contains('PostgrestException') ||
        rawMsg.contains('DatabaseException') ||
        rawMsg.contains('SQLiteException') ||
        rawMsg.contains('constraint') ||
        rawMsg.contains('violates')) {
      userFriendlyMsg = 'Failed to sync data with the server. Please pull to refresh.';
    }

    return AppError(
      message: userFriendlyMsg,
      timestamp: DateTime.now(),
    );
  }
}
