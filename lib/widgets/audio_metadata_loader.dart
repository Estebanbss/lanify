import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_utils.dart';

/// Métodos para cargar metadatos y artwork de archivos de audio.
class AudioMetadataLoader {
  /// Cache para evitar recrear archivos temporales
  static final Map<String, String> _artworkCache = {};

  /// Limpia archivos de artwork temporales corruptos
  static Future<void> cleanupCorruptedArtwork() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir
          .listSync()
          .where(
            (entity) => entity is File && entity.path.contains('_cover.jpg'),
          )
          .cast<File>();

      for (final file in files) {
        try {
          if (await file.length() == 0) {
            await file.delete();
          }
        } catch (_) {
          // Ignorar errores de limpieza
        }
      }
    } catch (_) {
      // Ignorar errores de limpieza
    }
  }

  /// Extrae metadatos y artwork para un archivo de audio.
  static Future<MediaItem> extractMetadataForFile(File file) async {
    String title = getFileName(file.path);
    String artist = 'Unknown Artist';
    String album = 'Unknown Album';
    Uri? artUri;

    try {
      // Usar timeout para prevenir bloqueos
      final metadata = await MetadataRetriever.fromFile(
        file,
      ).timeout(const Duration(seconds: 5));

      if (metadata.trackName != null && metadata.trackName!.isNotEmpty) {
        title = metadata.trackName!;
      }
      if (metadata.trackArtistNames != null &&
          metadata.trackArtistNames!.isNotEmpty) {
        artist = metadata.trackArtistNames!.join(', ');
      }
      if (metadata.albumName != null && metadata.albumName!.isNotEmpty) {
        album = metadata.albumName!;
      }

      // Manejo más robusto del artwork
      if (metadata.albumArt != null && metadata.albumArt!.isNotEmpty) {
        try {
          // Verificar que el artwork no esté corrupto
          if (metadata.albumArt!.length > 10 &&
              metadata.albumArt!.length < 10 * 1024 * 1024) {
            final tempDir = await getTemporaryDirectory();
            final fileName = '${file.uri.pathSegments.last}_cover.jpg';
            final coverFile = File('${tempDir.path}/$fileName');

            // Usar cache para evitar recrear archivos
            if (_artworkCache.containsKey(file.path) &&
                await File(_artworkCache[file.path]!).exists()) {
              artUri = Uri.file(_artworkCache[file.path]!);
            } else {
              // Escribir con timeout
              await coverFile
                  .writeAsBytes(metadata.albumArt!)
                  .timeout(const Duration(seconds: 2));

              // Verificar que el archivo se escribió correctamente
              if (await coverFile.exists() && await coverFile.length() > 0) {
                _artworkCache[file.path] = coverFile.path;
                artUri = Uri.file(coverFile.path);
              }
            }
          }
        } catch (e) {
          // Silenciar errores de artwork para evitar crashes
          debugPrint('Error processing artwork for ${file.path}: $e');
        }
      }
    } catch (e) {
      // Manejo más detallado de errores de metadata
      debugPrint('Error extracting metadata for ${file.path}: $e');
    }

    return MediaItem(
      id: file.path,
      title: title,
      artist: artist,
      album: album,
      artUri: artUri,
      extras: {'path': file.path, 'hasMetadata': true},
    );
  }
}
