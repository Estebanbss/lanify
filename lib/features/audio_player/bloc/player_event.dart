import 'package:equatable/equatable.dart';
import '../../audio_explorer/models/audio_file_item.dart';

/// Eventos del reproductor de audio
abstract class PlayerEvent extends Equatable {
  const PlayerEvent();

  @override
  List<Object?> get props => [];
}

/// Reproducir archivo específico
class PlayAudio extends PlayerEvent {
  final AudioFileItem audioFile;
  final List<AudioFileItem> playlist;

  const PlayAudio({required this.audioFile, required this.playlist});

  @override
  List<Object?> get props => [audioFile, playlist];
}

/// Pausar/reanudar reproducción
class TogglePlayPause extends PlayerEvent {
  const TogglePlayPause();
}

/// Detener reproducción
class StopPlayback extends PlayerEvent {
  const StopPlayback();
}

/// Siguiente canción
class PlayNext extends PlayerEvent {
  const PlayNext();
}

/// Canción anterior
class PlayPrevious extends PlayerEvent {
  const PlayPrevious();
}

/// Buscar posición específica
class SeekTo extends PlayerEvent {
  final Duration position;

  const SeekTo(this.position);

  @override
  List<Object?> get props => [position];
}

/// Actualizar playlist
class UpdatePlaylist extends PlayerEvent {
  final List<AudioFileItem> playlist;

  const UpdatePlaylist(this.playlist);

  @override
  List<Object?> get props => [playlist];
}

/// Actualizar estado interno del player
class UpdatePlayerState extends PlayerEvent {
  final bool? isPlaying;
  final bool? isLoading;
  final Duration? currentPosition;
  final Duration? totalDuration;

  const UpdatePlayerState({
    this.isPlaying,
    this.isLoading,
    this.currentPosition,
    this.totalDuration,
  });

  @override
  List<Object?> get props => [
    isPlaying,
    isLoading,
    currentPosition,
    totalDuration,
  ];
}

/// Manejar fin de track
class HandleTrackCompleted extends PlayerEvent {
  const HandleTrackCompleted();
}
