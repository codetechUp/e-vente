import 'dart:math';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseClient _client;

  StorageService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<String> uploadProductImage({
    required XFile file,
    String bucket = 'products',
  }) async {
    final bytes = await file.readAsBytes();
    final extension = _extFromPath(file.name);
    final contentType = _contentTypeFromExt(extension);

    final fileName =
        'product_${DateTime.now().millisecondsSinceEpoch}_${_rand(6)}.$extension';
    final path = 'images/$fileName';

    await _uploadBinary(
      bucket: bucket,
      path: path,
      bytes: bytes,
      contentType: contentType,
    );

    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> _uploadBinary({
    required String bucket,
    required String path,
    required Uint8List bytes,
    String? contentType,
  }) async {
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
          ),
        );
  }

  String _extFromPath(String name) {
    final idx = name.lastIndexOf('.');
    if (idx == -1) return 'jpg';
    final ext = name.substring(idx + 1).toLowerCase();
    if (ext.isEmpty) return 'jpg';
    return ext;
  }

  String _contentTypeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }

  String _rand(int len) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
