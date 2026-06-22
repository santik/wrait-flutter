import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class DraftAudioPathCodec {
  static const String _cacheScheme = 'app-cache://';

  static Future<String> store(String audioPath) async {
    final trimmedPath = audioPath.trim();
    if (trimmedPath.isEmpty) {
      return trimmedPath;
    }

    final cacheDirectory = await getTemporaryDirectory();
    final normalizedCachePath = path.normalize(cacheDirectory.path);
    final normalizedAudioPath = path.normalize(trimmedPath);

    if (_isWithinDirectory(
      directoryPath: normalizedCachePath,
      filePath: normalizedAudioPath,
    )) {
      final relativePath = path.relative(
        normalizedAudioPath,
        from: normalizedCachePath,
      );
      return '$_cacheScheme$relativePath';
    }

    return normalizedAudioPath;
  }

  static Future<String> resolve(String storedAudioPath) async {
    final trimmedPath = storedAudioPath.trim();
    if (trimmedPath.isEmpty) {
      return trimmedPath;
    }

    if (trimmedPath.startsWith(_cacheScheme)) {
      final relativePath = trimmedPath.substring(_cacheScheme.length);
      final cacheDirectory = await getTemporaryDirectory();
      return path.normalize(path.join(cacheDirectory.path, relativePath));
    }

    final normalizedAudioPath = path.normalize(trimmedPath);
    if (await File(normalizedAudioPath).exists()) {
      return normalizedAudioPath;
    }

    final fileName = path.basename(normalizedAudioPath);
    if (fileName.isEmpty || fileName == trimmedPath) {
      return normalizedAudioPath;
    }

    final cacheDirectory = await getTemporaryDirectory();
    final fallbackPath = path.normalize(
      path.join(cacheDirectory.path, fileName),
    );
    if (normalizedAudioPath == fallbackPath) {
      return normalizedAudioPath;
    }

    if (await File(fallbackPath).exists()) {
      return fallbackPath;
    }

    return normalizedAudioPath;
  }

  static bool _isWithinDirectory({
    required String directoryPath,
    required String filePath,
  }) {
    return path.equals(path.dirname(filePath), directoryPath) ||
        path.isWithin(directoryPath, filePath);
  }
}
