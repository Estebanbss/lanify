import 'dart:io';
import 'package:audio_service/audio_service.dart';

/// Métodos de control de reproducción y playlist para el explorador de audio.
class AudioPlaybackController {
  static int findTrackIndex(List<File> playlist, File audioFile) {
    return playlist.indexWhere((file) => file.path == audioFile.path);
  }

  static MediaItem createBasicMediaItem(File file) {
    return MediaItem(
      id: file.path,
      title: file.uri.pathSegments.last,
      artist: 'Unknown Artist',
      album: 'Unknown Album',
      extras: {'path': file.path},
    );
  }
}
