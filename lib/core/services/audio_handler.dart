import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// AudioHandler personalizado para integración con el sistema de control de medios
class LanifyAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _audioPlayer;
  void Function()? onSkipToNext;
  void Function()? onSkipToPrevious;
  void Function()? onPlay;
  void Function()? onPause;
  void Function(Duration?)? onDurationChanged;
  LanifyAudioHandler() : _audioPlayer = AudioPlayer() {
    _initializeAudioHandler();
  }

  void _initializeAudioHandler() {
    // Listeners para sincronizar el estado del player con el audio service
    _audioPlayer.playerStateStream.listen(_broadcastState);
    _audioPlayer.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(updatePosition: position));
    });
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null && mediaItem.value != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: duration));
        if (onDurationChanged != null) {
          onDurationChanged!(duration);
        }
      }
    });
  }

  void _broadcastState(PlayerState playerState) {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playerState.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState:
            const {
              ProcessingState.idle: AudioProcessingState.idle,
              ProcessingState.loading: AudioProcessingState.loading,
              ProcessingState.buffering: AudioProcessingState.buffering,
              ProcessingState.ready: AudioProcessingState.ready,
              ProcessingState.completed: AudioProcessingState.completed,
            }[playerState.processingState] ??
            AudioProcessingState.idle,
        playing: playerState.playing,
      ),
    );
  }

  @override
  Future<void> play() async {
    if (onPlay != null) {
      onPlay!();
    }
    await _audioPlayer.play();
  }

  @override
  Future<void> pause() async {
    if (onPause != null) {
      onPause!();
    }
    await _audioPlayer.pause();
  }

  @override
  Future<void> stop() async {
    await _audioPlayer.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (onSkipToNext != null) {
      onSkipToNext!();
    }
    await super.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipToPrevious != null) {
      onSkipToPrevious!();
    }
    await super.skipToPrevious();
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    try {
      this.mediaItem.add(mediaItem);

      // Cargar el archivo de audio
      await _audioPlayer.setFilePath(mediaItem.id);

      // Inicializar el estado de reproducción
      playbackState.add(
        PlaybackState(
          controls: [
            MediaControl.skipToPrevious,
            MediaControl.play,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: AudioProcessingState.ready,
          playing: false,
        ),
      );

      // Reproducir automáticamente
      await play();
    } catch (e) {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
        ),
      );
      rethrow;
    }
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    queue.add(mediaItems);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    this.queue.add(queue);
  }

  /// Obtener la instancia del AudioPlayer para uso externo
  AudioPlayer get audioPlayer => _audioPlayer;

  /// Limpiar recursos
  Future<void> dispose() async {
    await _audioPlayer.dispose();
    await super.stop();
  }
}
