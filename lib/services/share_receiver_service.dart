import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class SharedContent {
  final String fullText;
  final String? extractedUrl;

  SharedContent({
    required this.fullText,
    this.extractedUrl,
  });

  @override
  String toString() => 'SharedContent(fullText: $fullText, extractedUrl: $extractedUrl)';
}

class ShareReceiverService {
  static final ShareReceiverService instance = ShareReceiverService._internal();
  ShareReceiverService._internal();

  StreamSubscription? _intentDataStreamSubscription;
  final StreamController<SharedContent> _sharedContentController =
      StreamController<SharedContent>.broadcast();

  Stream<SharedContent> get onSharedContent => _sharedContentController.stream;

  bool _isInitialized = false;

  void init() {
    if (_isInitialized) return;
    _isInitialized = true;

    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      debugPrint("[ShareReceiverService] Share receiver disabled for current platform.");
      return;
    }

    runZonedGuarded(() {
      try {
        // 1. Listen to media sharing stream (when app is in background/running)
        _intentDataStreamSubscription = ReceiveSharingIntent.instance
            .getMediaStream()
            .handleError((err, stack) {
          debugPrint("[ShareReceiverService] Handled stream error: $err");
        }).listen((List<SharedMediaFile> value) {
          _processSharedMediaFiles(value);
        }, onError: (err) {
          debugPrint("[ShareReceiverService] Error receiving sharing stream: $err");
        });

        // 2. Get initial media (when app was closed and opened via share sheet)
        ReceiveSharingIntent.instance
            .getInitialMedia()
            .then((List<SharedMediaFile> value) {
          if (value.isNotEmpty) {
            _processSharedMediaFiles(value);
            // Clear initial intent after processing
            ReceiveSharingIntent.instance.reset();
          }
        }).catchError((err, stack) {
          debugPrint("[ShareReceiverService] Error getting initial shared media: $err");
        });
      } catch (e) {
        debugPrint("[ShareReceiverService] Plugin initialization deferred (rebuild app): $e");
      }
    }, (error, stack) {
      debugPrint("[ShareReceiverService] Suppressed unhandled intent error: $error");
    });
  }

  void _processSharedMediaFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    for (final file in files) {
      // Shared text or link path is in file.path or file.message
      final String text = file.path.isNotEmpty
          ? file.path
          : (file.message ?? '');

      if (text.isNotEmpty) {
        final content = parseSharedText(text);
        debugPrint("[ShareReceiverService] Shared content received: $content");
        _sharedContentController.add(content);
        break;
      }
    }
  }

  static SharedContent parseSharedText(String text) {
    final String trimmed = text.trim();
    final urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final match = urlRegex.firstMatch(trimmed);
    final String? extractedUrl = match?.group(0);

    return SharedContent(
      fullText: trimmed,
      extractedUrl: extractedUrl,
    );
  }

  void dispose() {
    _intentDataStreamSubscription?.cancel();
    _sharedContentController.close();
    _isInitialized = false;
  }
}
