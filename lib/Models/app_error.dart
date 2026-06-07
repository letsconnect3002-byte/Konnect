class AppError {
  final String message;
  final String? code;
  final DateTime timestamp;
  
  const AppError({required this.message, this.code, required this.timestamp});
  
  factory AppError.from(Object e) {
    return AppError(
      message: e.toString().replaceAll('Exception: ', ''),
      timestamp: DateTime.now(),
    );
  }
}
