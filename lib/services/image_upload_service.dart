import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageUploadService {
  static Future<Uint8List> compressImageTo10Kb(Uint8List originalBytes) async {
    if (originalBytes.length <= 10 * 1024) {
      return originalBytes;
    }

    final image = img.decodeImage(originalBytes);
    if (image == null) return originalBytes;

    int width = 150;
    int height = (image.height * (width / image.width)).round();
    img.Image resized = img.copyResize(image, width: width, height: height);

    int quality = 80;
    Uint8List compressedBytes;
    do {
      compressedBytes =
          Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      if (compressedBytes.length <= 10 * 1024 || quality <= 10) {
        break;
      }
      quality -= 15;
      if (quality < 10) quality = 10;
    } while (compressedBytes.length > 10 * 1024);

    if (compressedBytes.length > 10 * 1024) {
      resized = img.copyResize(image, width: 80, height: 80);
      compressedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 15));
    }

    return compressedBytes;
  }

  static Future<String> uploadAvatarImage(
      int? userId, Uint8List compressedBytes) async {
    try {
      await Supabase.instance.client.storage
          .createBucket('avatars', const BucketOptions(public: true));
    } catch (_) {
      // Safe to ignore if bucket already exists
    }

    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String folderName = userId != null ? '$userId' : 'temp_user';
    final String fileName = '$folderName/avatar_$timestamp.jpg';

    await Supabase.instance.client.storage.from('avatars').uploadBinary(
          fileName,
          compressedBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    return Supabase.instance.client.storage
        .from('avatars')
        .getPublicUrl(fileName);
  }

  static Future<String> uploadTribeAvatarImage(
      String tribeId, Uint8List compressedBytes) async {
    try {
      await Supabase.instance.client.storage
          .createBucket('Tribe_avatar', const BucketOptions(public: true));
    } catch (_) {
      // Safe to ignore if bucket already exists
    }

    final String fileName = '$tribeId.jpg';

    await Supabase.instance.client.storage.from('Tribe_avatar').uploadBinary(
          fileName,
          compressedBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    return Supabase.instance.client.storage
        .from('Tribe_avatar')
        .getPublicUrl(fileName);
  }
}
