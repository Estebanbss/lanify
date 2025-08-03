import 'dart:io';

/// Utilidades para el manejo de archivos
class FileUtils {
  /// Obtiene el nombre de archivo sin la ruta
  static String getFileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  /// Obtiene la extensión de un archivo
  static String getFileExtension(String path) {
    final fileName = getFileName(path);
    final lastDot = fileName.lastIndexOf('.');
    return lastDot != -1 ? fileName.substring(lastDot) : '';
  }

  /// Formatea el tamaño de archivo en formato legible
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Utilidades para formateo de duración y tiempo
class DurationUtils {
  /// Formatea una duración en formato legible
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Convierte una posición en seconds a Duration
  static Duration secondsToDuration(double seconds) {
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// Convierte una Duration a seconds
  static double durationToSeconds(Duration duration) {
    return duration.inMilliseconds / 1000.0;
  }
}
