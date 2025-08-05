import 'package:equatable/equatable.dart';
import 'package:audio_service/audio_service.dart' as audio_service;
import 'dart:io';

/// Modelo que representa un archivo de audio con sus metadatos
class AudioFileItem extends Equatable {
  final File file;
  final audio_service.MediaItem? metadata;
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
      final uri = metadata!.artUri!;
      if (uri.isScheme('file')) {
        return uri.toFilePath();
      } else {
        // Si es una URI string, devolverla tal como está
        return uri.toString();
      }
    }

    return null;
  }

  AudioFileItem copyWith({
    File? file,
    audio_service.MediaItem? metadata,
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
