import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dart_tags/dart_tags.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';
import '../utils/file_utils.dart';

/// Servicio para cargar metadatos de archivos de audio con optimización de artwork
class MetadataService {
  static final Map<String, Uri?> _artworkCache = {};

  /// Stream de metadatos para múltiples archivos procesados secuencialmente
  Stream<MediaItem> loadMetadataStream(List<File> files) async* {
    debugPrint('[DEBUG] MetadataService: Procesando ${files.length} archivos');

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      try {
        // Solo log cada 10 archivos para no saturar la consola
        if (i % 10 == 0) {
          debugPrint(
            '[MetadataService] Procesando archivo $i/${files.length}: ${file.path}',
          );
        }
        final mediaItem = await loadSingleMetadata(file);
        yield mediaItem;
      } catch (e, stack) {
        debugPrint(
          '[MetadataService] ERROR al procesar ${file.path}: $e\n$stack',
        );
        yield _createBasicMediaItem(file);
      }

      // Solo delay cada 10 archivos para acelerar el proceso
      if (i % 10 == 0) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
    debugPrint('[DEBUG] MetadataService: Stream terminado completamente');
  }

  Future<MediaItem> loadSingleMetadata(File file) async {
    try {
      return await _extractMetadataForFile(file);
    } catch (e) {
      debugPrint('Error loading metadata for ${file.path}: $e');
      return _createBasicMediaItem(file);
    }
  }

  bool isAudioFile(File file) {
    return AppConstants.isAudioFile(file.path);
  }

  Future<MediaItem> _extractMetadataForFile(File file) async {
    String title = FileUtils.getFileName(file.path);
    String artist = 'Unknown Artist';
    String album = 'Unknown Album';
    Uri? artUri;

    try {
      debugPrint('[lanify][_extractMetadataForFile] Procesando: ${file.path}');

      // Intentar primero con ffprobe para mejor compatibilidad con FLAC
      final metadata = await _extractMetadataWithFfprobe(file);
      if (metadata != null) {
        title = metadata['title'] ?? title;
        artist = metadata['artist'] ?? artist;
        album = metadata['album'] ?? album;

        // Extraer artwork usando ffprobe/ffmpeg
        artUri = await _extractArtworkWithFfmpeg(file);

        debugPrint(
          '[lanify][ffprobe] Metadata extraído - Título: $title, Artista: $artist, Álbum: $album',
        );
      } else {
        // Fallback a dart_tags si ffprobe no está disponible
        debugPrint('[lanify][_extractMetadataForFile] Fallback a dart_tags');
        final tagProcessor = TagProcessor();
        final tags = await tagProcessor.getTagsFromByteArray(
          Future.value(await file.readAsBytes()),
        );

        if (tags.isNotEmpty) {
          final tag = tags.first;
          if (tag.tags['title']?.isNotEmpty == true) {
            title = tag.tags['title']!;
          }
          if (tag.tags['artist']?.isNotEmpty == true) {
            artist = tag.tags['artist']!;
          }
          if (tag.tags['album']?.isNotEmpty == true) {
            album = tag.tags['album']!;
          }
          artUri = await _processArtworkFromTags(file, tag);
        }
      }
    } catch (e, stack) {
      debugPrint(
        '[lanify][_extractMetadataForFile] ERROR en ${file.path}: $e\nStack: $stack',
      );
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

  /// Extrae metadatos usando ffprobe (más confiable para FLAC)
  Future<Map<String, String>?> _extractMetadataWithFfprobe(File file) async {
    try {
      final result = await Process.run('ffprobe', [
        '-v',
        'quiet',
        '-show_entries',
        'format_tags:stream_tags',
        '-of',
        'json',
        file.path,
      ]);

      if (result.exitCode == 0) {
        final jsonData = json.decode(result.stdout as String);
        final tags = <String, String>{};

        // Buscar tags en format.tags y streams[0].tags
        final formatTags = jsonData['format']?['tags'] as Map<String, dynamic>?;
        final streamTags =
            jsonData['streams']?[0]?['tags'] as Map<String, dynamic>?;

        // Combinar tags con prioridad a format_tags
        final allTags = <String, dynamic>{};
        if (streamTags != null) allTags.addAll(streamTags);
        if (formatTags != null) allTags.addAll(formatTags);

        // Mapear tags comunes (FLAC usa mayúsculas)
        final tagMapping = {
          'TITLE': 'title',
          'title': 'title',
          'Title': 'title',
          'ARTIST': 'artist',
          'artist': 'artist',
          'Artist': 'artist',
          'ALBUM': 'album',
          'album': 'album',
          'Album': 'album',
        };

        for (final entry in allTags.entries) {
          final mappedKey = tagMapping[entry.key];
          if (mappedKey != null && entry.value != null) {
            tags[mappedKey] = entry.value.toString();
          }
        }

        debugPrint('[lanify][ffprobe] Tags extraídos: $tags');
        return tags.isNotEmpty ? tags : null;
      }
    } catch (e) {
      debugPrint('[lanify][ffprobe] Error ejecutando ffprobe: $e');
    }
    return null;
  }

  /// Extrae artwork usando ffmpeg (más confiable para FLAC)
  Future<Uri?> _extractArtworkWithFfmpeg(File file) async {
    try {
      final filePath = file.path;
      final fileModified = await file.lastModified();
      final cacheKey = '$filePath:${fileModified.millisecondsSinceEpoch}';

      // Verificar cache primero
      if (_artworkCache.containsKey(cacheKey)) {
        return _artworkCache[cacheKey];
      }

      // Verificar si el archivo tiene artwork embebido
      final probeResult = await Process.run('ffprobe', [
        '-v',
        'quiet',
        '-select_streams',
        'v:0',
        '-show_entries',
        'stream=codec_name',
        '-of',
        'csv=p=0',
        file.path,
      ]);

      if (probeResult.exitCode != 0 ||
          (probeResult.stdout as String).trim().isEmpty) {
        // No hay artwork embebido
        _artworkCache[cacheKey] = null;
        return null;
      }

      // Crear directorio temporal para artwork
      final tempDir = await getTemporaryDirectory();
      final fileNameWithoutExt = FileUtils.getFileName(
        file.path,
      ).replaceAll(RegExp(r'\.[^.]*$'), '');
      final artworkFileName = '${fileNameWithoutExt}_cover.jpg';
      final artworkFile = File('${tempDir.path}/artwork/$artworkFileName');

      // Verificar si ya existe artwork en cache
      if (await artworkFile.exists()) {
        final artUri = artworkFile.uri;
        _artworkCache[cacheKey] = artUri;
        debugPrint(
          '[lanify][ffmpeg] Artwork cacheado encontrado: ${artworkFile.path}',
        );
        return artUri;
      }

      // Extraer artwork con ffmpeg
      await artworkFile.parent.create(recursive: true);

      final extractResult = await Process.run('ffmpeg', [
        '-i', file.path,
        '-an', // Sin audio
        '-vcodec', 'copy',
        '-y', // Sobrescribir
        artworkFile.path,
      ]);

      if (extractResult.exitCode == 0 && await artworkFile.exists()) {
        final fileSize = await artworkFile.length();
        if (fileSize > 0) {
          final artUri = artworkFile.uri;
          _artworkCache[cacheKey] = artUri;
          debugPrint(
            '[lanify][ffmpeg] Artwork extraído: ${artworkFile.path} ($fileSize bytes)',
          );
          return artUri;
        }
      }

      debugPrint(
        '[lanify][ffmpeg] No se pudo extraer artwork de: ${file.path}',
      );
      _artworkCache[cacheKey] = null;
      return null;
    } catch (e) {
      debugPrint('[lanify][ffmpeg] Error extrayendo artwork: $e');
      return null;
    }
  }

  Future<Uri?> _processArtworkFromTags(File file, Tag tag) async {
    final artworkData = tag.tags['picture'] ?? tag.tags['APIC'];
    if (artworkData == null || artworkData.isEmpty) {
      return null;
    }
    final filePath = file.path;
    final fileModified = await file.lastModified();
    final cacheKey = '$filePath:${fileModified.millisecondsSinceEpoch}';
    if (_artworkCache.containsKey(cacheKey)) {
      return _artworkCache[cacheKey];
    }
    try {
      debugPrint(
        '[lanify][_processArtworkFromTags] Procesando artwork: ${file.path}',
      );
      List<int> artworkBytes;
      if (artworkData is List<int>) {
        artworkBytes = artworkData;
      } else if (artworkData is String) {
        return null;
      } else {
        return null;
      }
      if (artworkBytes.length > 100) {
        final tempDir = await getTemporaryDirectory();
        final fileNameWithoutExt = FileUtils.getFileName(
          file.path,
        ).replaceAll(RegExp(r'\.[^.]*$'), '');
        final fileName = '${fileNameWithoutExt}_cover.jpg';
        final artworkFile = File('${tempDir.path}/artwork/$fileName');
        if (await artworkFile.exists()) {
          final existingSize = await artworkFile.length();
          if (existingSize > 0 && existingSize == artworkBytes.length) {
            final artUri = artworkFile.uri;
            _artworkCache[cacheKey] = artUri;
            return artUri;
          }
        }
        await artworkFile.parent.create(recursive: true);
        await artworkFile.writeAsBytes(artworkBytes);
        if (await artworkFile.exists() && await artworkFile.length() > 0) {
          final artUri = artworkFile.uri;
          _artworkCache[cacheKey] = artUri;
          debugPrint(
            '[lanify][_processArtworkFromTags] New artwork saved for ${file.path}: ${artworkFile.path}',
          );
          return artUri;
        }
      }
    } catch (e, stack) {
      debugPrint(
        '[lanify][_processArtworkFromTags] ERROR en ${file.path}: $e\nStack: $stack',
      );
    }
    _artworkCache[cacheKey] = null;
    return null;
  }

  MediaItem _createBasicMediaItem(File file) {
    return MediaItem(
      id: file.path,
      title: FileUtils.getFileName(file.path),
      artist: 'Unknown Artist',
      album: 'Unknown Album',
      extras: {'path': file.path, 'hasMetadata': false},
    );
  }

  void clearArtworkCache() {
    _artworkCache.clear();
    debugPrint('Artwork cache cleared');
  }

  Map<String, int> getCacheStats() {
    return {
      'cached_items': _artworkCache.length,
      'non_null_artworks': _artworkCache.values
          .where((uri) => uri != null)
          .length,
    };
  }
}
