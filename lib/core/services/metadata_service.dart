import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';
import '../utils/file_utils.dart';

/// Servicio para cargar metadatos de archivos de audio con optimización de artwork
class MetadataService {
  static final Map<String, Uri?> _artworkCache = {};

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

      // Optimización del manejo del artwork
      artUri = await _processArtwork(file, metadata);
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

  /// Procesa artwork con cache y optimizaciones
  Future<Uri?> _processArtwork(File file, Metadata metadata) async {
    if (metadata.albumArt?.isEmpty != false) {
      return null;
    }

    final filePath = file.path;
    final fileModified = await file.lastModified();
    final cacheKey = '$filePath:${fileModified.millisecondsSinceEpoch}';

    // Verificar cache
    if (_artworkCache.containsKey(cacheKey)) {
      return _artworkCache[cacheKey];
    }

    try {
      if (metadata.albumArt!.length > 100) {
        // Mínimo 100 bytes para una imagen válida
        final tempDir = await getTemporaryDirectory();
        final fileNameWithoutExt = FileUtils.getFileName(
          file.path,
        ).replaceAll(RegExp(r'\.[^.]*$'), '');
        final fileName = '${fileNameWithoutExt}_cover.jpg';
        final artworkFile = File('${tempDir.path}/artwork/$fileName');

        // Verificar si el archivo ya existe y es válido
        if (await artworkFile.exists()) {
          final existingSize = await artworkFile.length();
          if (existingSize > 0 && existingSize == metadata.albumArt!.length) {
            // El archivo ya existe con el mismo tamaño, reutilizarlo
            final artUri = artworkFile.uri;
            _artworkCache[cacheKey] = artUri;
            return artUri;
          }
        }

        // Crear directorio si no existe
        await artworkFile.parent.create(recursive: true);

        // Guardar artwork solo si no existe o es diferente
        await artworkFile.writeAsBytes(metadata.albumArt!);
        if (await artworkFile.exists() && await artworkFile.length() > 0) {
          final artUri = artworkFile.uri;
          _artworkCache[cacheKey] = artUri;
          debugPrint('New artwork saved for ${file.path}: ${artworkFile.path}');
          return artUri;
        }
      }
    } catch (e) {
      debugPrint('Error processing artwork for ${file.path}: $e');
    }

    // Cache null result para evitar reintento
    _artworkCache[cacheKey] = null;
    return null;
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

  /// Limpia el cache de artwork (útil cuando hay cambios en archivos)
  static void clearArtworkCache() {
    _artworkCache.clear();
    debugPrint('Artwork cache cleared');
  }

  /// Obtiene estadísticas del cache
  static Map<String, int> getCacheStats() {
    return {
      'cached_items': _artworkCache.length,
      'non_null_artworks': _artworkCache.values
          .where((uri) => uri != null)
          .length,
    };
  }
}
