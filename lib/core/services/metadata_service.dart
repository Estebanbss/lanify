import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';
import '../utils/file_utils.dart';

/// Servicio para cargar metadatos de archivos de audio sin cache
class MetadataService {
  /// Stream de metadatos para múltiples archivos
  Stream<MediaItem> loadMetadataStream(List<File> files) async* {
    for (final file in files) {
      try {
        final metadata = await _extractMetadataForFile(file);
        yield metadata;
      } catch (e) {
        debugPrint('Error loading metadata for ${file.path}: $e');
        // Yield basic metadata even on error
        yield _createBasicMediaItem(file);
      }
    }
  }

  /// Extrae metadatos para un archivo específico
  Future<MediaItem> loadSingleMetadata(File file) async {
    try {
      return await _extractMetadataForFile(file);
    } catch (e) {
      debugPrint('Error loading metadata for ${file.path}: $e');
      return _createBasicMediaItem(file);
    }
  }

  /// Verifica si un archivo es de audio
  bool isAudioFile(File file) {
    return AppConstants.isAudioFile(file.path);
  }

  /// Extrae metadatos de un archivo de audio
  Future<MediaItem> _extractMetadataForFile(File file) async {
    String title = FileUtils.getFileName(file.path);
    String artist = 'Unknown Artist';
    String album = 'Unknown Album';
    Uri? artUri;

    try {
      final metadata = await MetadataRetriever.fromFile(
        file,
      ).timeout(const Duration(seconds: 5));

      if (metadata.trackName?.isNotEmpty == true) {
        title = metadata.trackName!;
      }
      if (metadata.trackArtistNames?.isNotEmpty == true) {
        artist = metadata.trackArtistNames!.join(', ');
      }
      if (metadata.albumName?.isNotEmpty == true) {
        album = metadata.albumName!;
      }

      // Manejo del artwork
      if (metadata.albumArt?.isNotEmpty == true) {
        try {
          if (metadata.albumArt!.length > 100) {
            // Mínimo 100 bytes para una imagen válida
            final tempDir = await getTemporaryDirectory();
            final fileNameWithoutExt = FileUtils.getFileName(
              file.path,
            ).replaceAll(RegExp(r'\.[^.]*$'), '');
            final fileName = '${fileNameWithoutExt}_cover.jpg';
            final artworkFile = File('${tempDir.path}/artwork/$fileName');

            // Crear directorio si no existe
            await artworkFile.parent.create(recursive: true);

            await artworkFile.writeAsBytes(metadata.albumArt!);
            if (await artworkFile.exists() && await artworkFile.length() > 0) {
              artUri = artworkFile.uri;
              debugPrint('Artwork saved for ${file.path}: ${artworkFile.path}');
            }
          }
        } catch (e) {
          debugPrint('Error saving artwork for ${file.path}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error extracting metadata for ${file.path}: $e');
    }

    return MediaItem(
      id: file.path,
      title: title,
      artist: artist,
      album: album,
      artUri: artUri,
      extras: {
        'path': file.path,
        'hasMetadata': true,
        'fileSize': await file.length(),
      },
    );
  }

  /// Crea MediaItem básico sin metadatos
  MediaItem _createBasicMediaItem(File file) {
    return MediaItem(
      id: file.path,
      title: FileUtils.getFileName(file.path),
      artist: 'Unknown Artist',
      album: 'Unknown Album',
      extras: {'path': file.path, 'hasMetadata': false},
    );
  }
}
