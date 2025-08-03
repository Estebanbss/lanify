import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:audio_service/audio_service.dart';

/// Modelo para representar un archivo de audio con sus metadatos
class AudioFileItem extends Equatable {
  final File file;
  final MediaItem? metadata;
  final bool isCurrentlyPlaying;

  const AudioFileItem({
    required this.file,
    this.metadata,
    this.isCurrentlyPlaying = false,
  });

  /// Nombre del archivo sin extensión
  String get fileName {
    final name = file.uri.pathSegments.last;
    final lastDot = name.lastIndexOf('.');
    return lastDot != -1 ? name.substring(0, lastDot) : name;
  }

  /// Extensión del archivo
  String get fileExtension {
    final name = file.uri.pathSegments.last;
    final lastDot = name.lastIndexOf('.');
    return lastDot != -1 ? name.substring(lastDot + 1).toLowerCase() : '';
  }

  /// Propiedades de conveniencia para acceso rápido a metadatos
  String get title => metadata?.title ?? fileName;
  String get artist => metadata?.artist ?? 'Artista Desconocido';
  String get album => metadata?.album ?? 'Álbum Desconocido';
  Duration? get duration => metadata?.duration;

  /// Crear copia con nuevos metadatos
  AudioFileItem copyWith({
    File? file,
    MediaItem? metadata,
    bool? isCurrentlyPlaying,
  }) {
    return AudioFileItem(
      file: file ?? this.file,
      metadata: metadata ?? this.metadata,
      isCurrentlyPlaying: isCurrentlyPlaying ?? this.isCurrentlyPlaying,
    );
  }

  @override
  List<Object?> get props => [file.path, metadata, isCurrentlyPlaying];
}
