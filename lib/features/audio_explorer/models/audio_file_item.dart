import 'package:equatable/equatable.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:io';

/// Modelo que representa un archivo de audio con sus metadatos
class AudioFileItem extends Equatable {
  final File file;
  final MediaItem? metadata;
  final bool isCurrentlyPlaying;
  final String? artworkPath;

  const AudioFileItem({
    required this.file,
    this.metadata,
    this.isCurrentlyPlaying = false,
    this.artworkPath,
  });

  String get fileName => file.path.split(Platform.pathSeparator).last;
  String get filePath => file.path;
  String get title => metadata?.title ?? fileName;
  String get artist => metadata?.artist ?? 'Unknown Artist';
  String get album => metadata?.album ?? 'Unknown Album';
  Duration get duration => metadata?.duration ?? Duration.zero;

  /// Obtiene la ruta del artwork desde los metadatos o el campo artworkPath
  String? get effectiveArtworkPath {
    // Primero intentar desde el campo artworkPath
    if (artworkPath != null && artworkPath!.isNotEmpty) {
      return artworkPath;
    }

    // Luego intentar desde metadata.artUri
    if (metadata?.artUri != null) {
      return metadata!.artUri!.toFilePath();
    }

    return null;
  }

  /// Convierte este AudioFileItem a MediaItem para el player
  MediaItem toMediaItem() {
    return MediaItem(
      id: file.path,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artUri: effectiveArtworkPath != null
          ? Uri.file(effectiveArtworkPath!)
          : metadata?.artUri,
    );
  }

  AudioFileItem copyWith({
    File? file,
    MediaItem? metadata,
    bool? isCurrentlyPlaying,
    String? artworkPath,
  }) {
    return AudioFileItem(
      file: file ?? this.file,
      metadata: metadata ?? this.metadata,
      isCurrentlyPlaying: isCurrentlyPlaying ?? this.isCurrentlyPlaying,
      artworkPath: artworkPath ?? this.artworkPath,
    );
  }

  @override
  List<Object?> get props => [
    file.path,
    metadata,
    isCurrentlyPlaying,
    artworkPath,
  ];
}
