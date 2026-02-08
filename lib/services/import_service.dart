import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

class ImportPayload {
  ImportPayload({
    required this.hash,
    required this.data,
    required this.files,
  });

  final String hash;
  final Map<String, dynamic> data;
  final Map<String, List<int>> files;
}

class ImportService {
  static Future<ImportPayload> loadZip(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = <String, List<int>>{};
    Map<String, dynamic>? data;
    String? hash;

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final content = file.content as List<int>;
      if (file.name == 'recipe.json') {
        final jsonMap = jsonDecode(utf8.decode(content)) as Map<String, dynamic>;
        hash = jsonMap['hash']?.toString();
        data = Map<String, dynamic>.from(jsonMap['data'] as Map);
      } else {
        files[file.name] = content;
      }
    }

    if (data == null) {
      throw Exception('recipe.json が見つかりません');
    }

    final canonical = jsonEncode(data);
    final computedHash = sha256.convert(utf8.encode(canonical)).toString();
    final finalHash = hash ?? computedHash;

    return ImportPayload(
      hash: finalHash,
      data: data,
      files: files,
    );
  }
}
