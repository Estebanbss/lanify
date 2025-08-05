import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:process/process.dart';

/// Servicio para escribir metadatos a archivos de audio
/// Utiliza múltiples estrategias dependiendo de la plataforma
class MetadataWriterService {
  static const ProcessManager _processManager = LocalProcessManager();

  /// Escribir metadatos completos a un archivo de audio
  static Future<bool> writeMetadata({
    required File audioFile,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
    String? year,
    String? trackNumber,
    String? composer,
    String? lyrics,
    Uint8List? artworkBytes,
    Map<String, String>? customMetadata,
  }) async {
    try {
      // Estrategia 1: Intentar usar ffmpeg si está disponible
      if (await _isFFmpegAvailable()) {
        return await _writeWithFFmpeg(
          audioFile: audioFile,
          title: title,
          artist: artist,
          album: album,
          albumArtist: albumArtist,
          genre: genre,
          year: year,
          trackNumber: trackNumber,
          composer: composer,
          lyrics: lyrics,
          artworkBytes: artworkBytes,
          customMetadata: customMetadata,
        );
      }

      // Estrategia 2: Para Android, intentar usar bibliotecas nativas
      if (Platform.isAndroid) {
        return await _writeWithAndroidMethod(
          audioFile: audioFile,
          title: title,
          artist: artist,
          album: album,
          albumArtist: albumArtist,
          genre: genre,
          year: year,
          trackNumber: trackNumber,
          composer: composer,
          lyrics: lyrics,
          artworkBytes: artworkBytes,
          customMetadata: customMetadata,
        );
      }

      // Estrategia 3: Fallback - solo logging y retorno falso
      debugPrint('No hay método de escritura disponible para esta plataforma');
      return false;
    } catch (e) {
      debugPrint('Error escribiendo metadatos: $e');
      return false;
    }
  }

  /// Verificar si ffmpeg está disponible en el sistema
  static Future<bool> _isFFmpegAvailable() async {
    try {
      final result = await _processManager.run(['ffmpeg', '-version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Escribir metadatos usando ffmpeg
  static Future<bool> _writeWithFFmpeg({
    required File audioFile,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
    String? year,
    String? trackNumber,
    String? composer,
    String? lyrics,
    Uint8List? artworkBytes,
    Map<String, String>? customMetadata,
  }) async {
    try {
      final originalPath = audioFile.path;
      final tempPath = '$originalPath.tmp';

      List<String> command = [
        'ffmpeg',
        '-i', originalPath,
        '-c', 'copy', // Copiar streams sin recodificar
      ];

      // Agregar metadatos estándar
      if (title != null && title.isNotEmpty) {
        command.addAll(['-metadata', 'title=$title']);
      }
      if (artist != null && artist.isNotEmpty) {
        command.addAll(['-metadata', 'artist=$artist']);
      }
      if (album != null && album.isNotEmpty) {
        command.addAll(['-metadata', 'album=$album']);
      }
      if (albumArtist != null && albumArtist.isNotEmpty) {
        command.addAll(['-metadata', 'album_artist=$albumArtist']);
      }
      if (genre != null && genre.isNotEmpty) {
        command.addAll(['-metadata', 'genre=$genre']);
      }
      if (year != null && year.isNotEmpty) {
        command.addAll(['-metadata', 'date=$year']);
      }
      if (trackNumber != null && trackNumber.isNotEmpty) {
        command.addAll(['-metadata', 'track=$trackNumber']);
      }
      if (composer != null && composer.isNotEmpty) {
        command.addAll(['-metadata', 'composer=$composer']);
      }
      if (lyrics != null && lyrics.isNotEmpty) {
        command.addAll(['-metadata', 'lyrics=$lyrics']);
      }

      // Agregar metadatos personalizados
      if (customMetadata != null) {
        for (final entry in customMetadata.entries) {
          if (entry.value.isNotEmpty) {
            command.addAll(['-metadata', '${entry.key}=${entry.value}']);
          }
        }
      }

      // Manejar artwork si se proporciona
      String? artworkTempPath;
      if (artworkBytes != null) {
        artworkTempPath = '${audioFile.parent.path}/temp_artwork.jpg';
        await File(artworkTempPath).writeAsBytes(artworkBytes);
        command.addAll(['-i', artworkTempPath]);
        command.addAll(['-map', '0', '-map', '1']);
        command.addAll(['-disposition:v', 'attached_pic']);
      }

      command.addAll(['-y', tempPath]); // Sobrescribir archivo temporal

      debugPrint('Ejecutando ffmpeg: ${command.join(' ')}');

      final result = await _processManager.run(command);

      // Limpiar archivo temporal de artwork
      if (artworkTempPath != null) {
        try {
          await File(artworkTempPath).delete();
        } catch (e) {
          debugPrint('Error eliminando artwork temporal: $e');
        }
      }

      if (result.exitCode == 0) {
        // Reemplazar archivo original con el temporal
        await File(tempPath).rename(originalPath);
        debugPrint('Metadatos escritos exitosamente con ffmpeg');
        return true;
      } else {
        debugPrint('Error en ffmpeg: ${result.stderr}');
        // Limpiar archivo temporal si falló
        try {
          await File(tempPath).delete();
        } catch (e) {
          // Ignorar errores de limpieza
        }
        return false;
      }
    } catch (e) {
      debugPrint('Error en _writeWithFFmpeg: $e');
      return false;
    }
  }

  /// Método para Android (placeholder - podría usar ExoPlayer o MediaMetadataRetriever)
  static Future<bool> _writeWithAndroidMethod({
    required File audioFile,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
    String? year,
    String? trackNumber,
    String? composer,
    String? lyrics,
    Uint8List? artworkBytes,
    Map<String, String>? customMetadata,
  }) async {
    // TODO: Implementar usando Android MediaMetadataRetriever o similar
    // Por ahora, retornar false para usar fallback
    debugPrint('Escritura de metadatos en Android no implementada aún');
    return false;
  }

  /// Verificar qué método de escritura está disponible
  static Future<String> getAvailableMethod() async {
    if (await _isFFmpegAvailable()) {
      return 'ffmpeg';
    }
    if (Platform.isAndroid) {
      return 'android-native (no implementado)';
    }
    return 'ninguno disponible';
  }

  /// Instalar ffmpeg automáticamente en algunas plataformas
  static Future<bool> tryInstallFFmpeg() async {
    try {
      if (Platform.isLinux) {
        // Intentar instalar con apt o snap
        final aptResult = await _processManager.run(['which', 'apt']);
        if (aptResult.exitCode == 0) {
          debugPrint('Intenta instalar ffmpeg con: sudo apt install ffmpeg');
          return false; // No podemos instalar automáticamente por permisos
        }
      } else if (Platform.isWindows) {
        debugPrint(
          'Para Windows, descarga ffmpeg desde https://ffmpeg.org/download.html',
        );
        return false;
      } else if (Platform.isMacOS) {
        // Intentar con brew
        final brewResult = await _processManager.run(['which', 'brew']);
        if (brewResult.exitCode == 0) {
          debugPrint('Intenta instalar ffmpeg con: brew install ffmpeg');
          return false;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error verificando instalación de ffmpeg: $e');
      return false;
    }
  }
}
