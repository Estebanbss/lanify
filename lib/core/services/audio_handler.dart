import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../../shared/models/media_item.dart' as local_media;

/// AudioHandler simplificado que usa audioplayers como motor de reproducción
class LanifyAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Callbacks para sincronización con el PlayerBloc
  void Function()? onSkipToNext;
  void Function()? onSkipToPrevious;
  void Function()? onPlay;
  void Function()? onPause;
  void Function(Duration?)? onDurationChanged;

  late StreamSubscription<PlayerState> _playerStateSubscription;
  late StreamSubscription<Duration> _positionSubscription;
  late StreamSubscription<Duration> _durationSubscription;
  late StreamSubscription<void> _playerCompleteSubscription;

  LanifyAudioHandler() {
    _initializeAudioHandler();
  }

  void _initializeAudioHandler() {
    // Sincronizar estado del reproductor con audio service
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen(
      _broadcastState,
    );

    // Actualizar posición en tiempo real
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      playbackState.add(playbackState.value.copyWith(updatePosition: position));
    });

    // Actualizar duración cuando cambie
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (mediaItem.value != null) {
        final currentItem = mediaItem.value!;
        mediaItem.add(
          MediaItem(
            id: currentItem.id,
            title: currentItem.title,
            artist: currentItem.artist,
            album: currentItem.album,
            duration: duration,
            artUri: currentItem.artUri,
          ),
        );

        // Notificar al bloc sobre el cambio de duración
        onDurationChanged?.call(duration);
      }
    });

    // Listener para cuando termina una canción
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      // Notificar que la canción terminó - esto activará PlayNext en el bloc
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.completed,
        ),
      );
    });
  }

  void _broadcastState(PlayerState playerState) {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          playerState == PlayerState.playing
              ? MediaControl.pause
              : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _mapPlayerStateToProcessingState(playerState),
        playing: playerState == PlayerState.playing,
      ),
    );
  }

  AudioProcessingState _mapPlayerStateToProcessingState(
    PlayerState playerState,
  ) {
    switch (playerState) {
      case PlayerState.stopped:
        return AudioProcessingState.idle;
      case PlayerState.playing:
        return AudioProcessingState.ready;
      case PlayerState.paused:
        return AudioProcessingState.ready;
      case PlayerState.completed:
        return AudioProcessingState.completed;
      default:
        return AudioProcessingState.idle;
    }
  }

  @override
  Future<void> play() async {
    onPlay?.call();
    await _audioPlayer.resume();
  }

  @override
  Future<void> pause() async {
    onPause?.call();
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
    onSkipToNext?.call();
    await super.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipToPrevious?.call();
    await super.skipToPrevious();
  }

  /// Reproducir un MediaItem usando audioplayers (sobrescribe el método base)
  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    try {
      // Establecer el MediaItem en el audio service
      this.mediaItem.add(mediaItem);

      // Parar cualquier reproducción previa
      await _audioPlayer.stop();

      // Reproducir el archivo usando audioplayers
      await _audioPlayer.play(DeviceFileSource(mediaItem.id));

      // Establecer estado inicial
      playbackState.add(
        PlaybackState(
          controls: [
            MediaControl.skipToPrevious,
            MediaControl.pause,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: AudioProcessingState.ready,
          playing: true,
        ),
      );
    } catch (e) {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
        ),
      );
      rethrow;
    }
  }

  /// Reproducir un MediaItem local (conversión a MediaItem de audio_service)
  Future<void> playLocalMediaItem(local_media.MediaItem localMediaItem) async {
    // Convertir nuestro MediaItem local al MediaItem de audio_service
    final audioServiceMediaItem = MediaItem(
      id: localMediaItem.id,
      title: localMediaItem.title,
      artist: localMediaItem.artist ?? 'Artista desconocido',
      album: localMediaItem.album ?? 'Álbum desconocido',
      duration: localMediaItem.duration,
      artUri: localMediaItem.artUri != null
          ? Uri.parse(localMediaItem.artUri!)
          : null,
    );

    await playMediaItem(audioServiceMediaItem);
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    queue.add(mediaItems);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    this.queue.add(queue);
  }

  /// Obtener la instancia del AudioPlayer para uso externo si es necesario
  AudioPlayer get audioPlayer => _audioPlayer;

  /// Limpiar recursos
  Future<void> dispose() async {
    await _playerStateSubscription.cancel();
    await _positionSubscription.cancel();
    await _durationSubscription.cancel();
    await _playerCompleteSubscription.cancel();
    await _audioPlayer.dispose();
    await super.stop();
  }
}
