import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_service/audio_service.dart';

import 'player_event.dart';
import 'player_state.dart' as player_state;
import '../../../core/services/audio_handler.dart';

/// BLoC para manejar el estado del reproductor de audio
class PlayerBloc extends Bloc<PlayerEvent, player_state.PlayerState> {
  final LanifyAudioHandler _audioHandler;
  final AudioPlayer _audioPlayer;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  PlayerBloc({LanifyAudioHandler? audioHandler})
    : _audioHandler = audioHandler ?? LanifyAudioHandler(),
      _audioPlayer = (audioHandler ?? LanifyAudioHandler()).audioPlayer,
      super(const player_state.PlayerState()) {
    // Conectar callbacks del handler con los métodos del bloc
    _audioHandler.onSkipToNext = () => add(const PlayNext());
    _audioHandler.onSkipToPrevious = () => add(const PlayPrevious());
    _audioHandler.onPlay = () => add(UpdatePlayerState(isPlaying: true));
    _audioHandler.onPause = () => add(UpdatePlayerState(isPlaying: false));
    _audioHandler.onDurationChanged = (duration) {
      if (duration != null) {
        add(UpdatePlayerState(totalDuration: duration));
      }
    };

    on<PlayAudio>(_onPlayAudio);
    on<TogglePlayPause>(_onTogglePlayPause);
    on<StopPlayback>(_onStopPlayback);
    on<PlayNext>(_onPlayNext);
    on<PlayPrevious>(_onPlayPrevious);
    on<SeekTo>(_onSeekTo);
    on<UpdatePlaylist>(_onUpdatePlaylist);
    on<UpdatePlayerState>(_onUpdatePlayerState);
    on<HandleTrackCompleted>(_onHandleTrackCompleted);
    _setupPlayerListeners();
  }

  /// Configurar listeners del reproductor
  void _setupPlayerListeners() {
    // Listener para cambios de estado del reproductor
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((
      playerState,
    ) {
      final isPlaying = playerState == PlayerState.playing;
      if (state.isPlaying != isPlaying) {
        add(UpdatePlayerState(isPlaying: isPlaying));
      }
    });

    // Listener para posición actual con throttle
    _positionSubscription = _audioPlayer.onPositionChanged
        .where(
          (position) => position.inSeconds != state.currentPosition.inSeconds,
        )
        .listen((position) {
          if (!isClosed) {
            add(UpdatePlayerState(currentPosition: position));
          }
        });

    // Listener para duración total
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (state.totalDuration != duration && !isClosed) {
        add(UpdatePlayerState(totalDuration: duration));
      }
    });

    // Listener para cuando termina una canción
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!isClosed) {
        add(const HandleTrackCompleted());
      }
    });

    // Listener adicional para el estado del AudioHandler (para detectar completed)
    _audioHandler.playbackState.listen((playbackState) {
      if (playbackState.processingState == AudioProcessingState.completed &&
          !isClosed) {
        add(const HandleTrackCompleted());
      }
    });
  }

  /// Reproducir audio específico
  Future<void> _onPlayAudio(
    PlayAudio event,
    Emitter<player_state.PlayerState> emit,
  ) async {
    try {
      // Actualizar playlist si es diferente
      final playlist = event.playlist;
      final currentIndex = playlist.indexWhere(
        (item) => item.file.path == event.audioFile.file.path,
      );

      if (currentIndex == -1) {
        emit(
          state.copyWith(
            isLoading: false,
            error: 'Canción no encontrada en la playlist',
          ),
        );
        return;
      }

      // Establecer currentAudioFile inmediatamente para mostrar los controles
      emit(
        state.copyWith(
          currentAudioFile: event.audioFile,
          playlist: playlist,
          currentIndex: currentIndex,
          isLoading: true,
          error: null,
        ),
      );

      // Parar cualquier reproducción previa y reproducir usando AudioHandler
      // Convertir a audio_service.MediaItem para el AudioHandler
      final audioServiceMediaItem = MediaItem(
        id: event.audioFile.file.path,
        title: event.audioFile.title,
        artist: event.audioFile.artist,
        album: event.audioFile.album,
        duration: event.audioFile.duration,
        artUri: event.audioFile.effectiveArtworkPath != null
            ? Uri.file(event.audioFile.effectiveArtworkPath!)
            : null,
      );
      await _audioHandler.playMediaItem(audioServiceMediaItem);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Error reproduciendo audio: $e',
        ),
      );
    }
  }

  /// Pausar/reanudar reproducción
  Future<void> _onTogglePlayPause(
    TogglePlayPause event,
    Emitter<player_state.PlayerState> emit,
  ) async {
    try {
      if (state.isPlaying) {
        await _audioHandler.pause();
      } else {
        await _audioHandler.play();
      }
    } catch (e) {
      emit(state.copyWith(error: 'Error al pausar/reanudar: $e'));
    }
  }

  /// Detener reproducción
  Future<void> _onStopPlayback(
    StopPlayback event,
    Emitter<player_state.PlayerState> emit,
  ) async {
    try {
      await _audioHandler.stop();
      emit(
        state.copyWith(
          currentAudioFile: null,
          currentIndex: -1,
          isPlaying: false,
          currentPosition: Duration.zero,
          totalDuration: Duration.zero,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: 'Error al detener: $e'));
    }
  }

  /// Reproducir siguiente canción
  Future<void> _onPlayNext(
    PlayNext event,
    Emitter<player_state.PlayerState> emit,
  ) async {
    if (!state.hasNext) return;

    final nextIndex = state.currentIndex + 1;
    final nextAudioFile = state.playlist[nextIndex];

    add(PlayAudio(audioFile: nextAudioFile, playlist: state.playlist));
  }

  /// Reproducir canción anterior
  Future<void> _onPlayPrevious(
    PlayPrevious event,
    Emitter<player_state.PlayerState> emit,
  ) async {
    if (!state.hasPrevious) return;

    final previousIndex = state.currentIndex - 1;
    final previousAudioFile = state.playlist[previousIndex];

    add(PlayAudio(audioFile: previousAudioFile, playlist: state.playlist));
  }

  /// Buscar posición específica
  Future<void> _onSeekTo(
    SeekTo event,
    Emitter<player_state.PlayerState> emit,
  ) async {
    try {
      await _audioHandler.seek(event.position);
    } catch (e) {
      emit(state.copyWith(error: 'Error al buscar posición: $e'));
    }
  }

  /// Actualizar playlist
  void _onUpdatePlaylist(
    UpdatePlaylist event,
    Emitter<player_state.PlayerState> emit,
  ) {
    emit(state.copyWith(playlist: event.playlist));
  }

  /// Actualizar estado del player
  void _onUpdatePlayerState(
    UpdatePlayerState event,
    Emitter<player_state.PlayerState> emit,
  ) {
    emit(
      state.copyWith(
        isPlaying: event.isPlaying,
        isLoading: event.isLoading,
        currentPosition: event.currentPosition,
        totalDuration: event.totalDuration,
      ),
    );
  }

  /// Manejar cuando termina una canción
  void _onHandleTrackCompleted(
    HandleTrackCompleted event,
    Emitter<player_state.PlayerState> emit,
  ) {
    if (state.hasNext) {
      add(const PlayNext());
    } else {
      add(const StopPlayback());
    }
  }

  @override
  Future<void> close() async {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    await _audioHandler.dispose();
    return super.close();
  }
}
