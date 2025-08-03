class AppConstants {
  static const String appName = 'Lanify';

  /// Formatos de audio soportados
  static const Set<String> supportedAudioExtensions = {
    '.mp3',
    '.flac',
    '.wav',
    '.aac',
    '.ogg',
    '.m4a',
    '.wma',
    '.opus',
    '.mp4',
    '.3gp',
  };

  static const int maxSearchResults = 100;
  static const Duration searchDebounceTime = Duration(milliseconds: 300);

  // Directorios por defecto
  static const String defaultMusicFolder = 'Music';
  static const String defaultDownloadsFolder = 'Downloads';

  // Configuración del reproductor
  static const Duration seekInterval = Duration(seconds: 10);
  static const double defaultVolume = 0.7;

  /// Verifica si un archivo es de audio basado en su extensión
  static bool isAudioFile(String filePath) {
    final extension = '.${filePath.split('.').last.toLowerCase()}';
    return supportedAudioExtensions.contains(extension);
  }
}
