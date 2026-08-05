void main() {
  final urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);
  final text = 'https://www.instagram.com/reel/DblUfEdvE36/?igsh=bmY3NnEwandzazg4';
  final match = urlRegex.firstMatch(text);
  print('Match: ${match?.group(0)}');
  final result = text.replaceAll(urlRegex, '').trim();
  print('Result: [$result]');
  print('Length: ${result.length}');
}
