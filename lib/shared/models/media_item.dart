import 'package:equatable/equatable.dart';

/// Modelo simple para representar un elemento de audio
class MediaItem extends Equatable {
  /// ID único del archivo (ruta del archivo)
  final String id;

  /// Título de la canción
  final String title;

  /// Artista
  final String? artist;

  /// Álbum
  final String? album;

  /// Duración en milisegundos (opcional)
  final Duration? duration;

  /// Imagen de portada (path local o base64)
  final String? artUri;

  const MediaItem({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.duration,
    this.artUri,
  });

  /// Constructor para crear desde archivo de audio
  factory MediaItem.fromFile({
    required String filePath,
    required String title,
    String? artist,
    String? album,
    Duration? duration,
    String? artUri,
  }) {
    return MediaItem(
      id: filePath,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artUri: artUri,
    );
  }

  /// Crear copia con cambios específicos
  MediaItem copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? artUri,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      artUri: artUri ?? this.artUri,
    );
  }

  @override
  List<Object?> get props => [id, title, artist, album, duration, artUri];

  @override
  String toString() => 'MediaItem(id: $id, title: $title, artist: $artist)';
}
