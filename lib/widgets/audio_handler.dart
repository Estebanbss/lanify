import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final List<MediaItem> _queue = [];
  int _currentIndex = 0;

  MyAudioHandler() {
    _init();
  }

  void _init() {
    // Escuchar cambios de estado del reproductor
    _player.playerStateStream.listen((state) {
      playbackState.add(PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (state.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _mapProcessingState(state.processingState),
        playing: state.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
      ));
    });

    // Escuchar cambios de posición
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    // Escuchar cuando termina una canción
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    _queue.addAll(mediaItems);
    queue.add(_queue);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    _queue.clear();
    _queue.addAll(queue);
    this.queue.add(_queue);
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    final index = _queue.indexOf(mediaItem);
    if (index != -1) {
      _currentIndex = index;
      await _setCurrentMediaItem();
    }
  }

  Future<void> _setCurrentMediaItem() async {
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      final mediaItem = _queue[_currentIndex];
      this.mediaItem.add(mediaItem);
      
      await _player.setAudioSource(
        AudioSource.uri(Uri.file(mediaItem.extras!['path'] as String)),
      );
    }
  }

  @override
  Future<void> play() async {
    if (_queue.isEmpty) return;
    
    if (_player.audioSource == null && _currentIndex < _queue.length) {
      await _setCurrentMediaItem();
    }
    
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(PlaybackState(
      controls: [],
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    mediaItem.add(null);
  }

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    
    _currentIndex = (_currentIndex + 1) % _queue.length;
    await _setCurrentMediaItem();
    await play();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    
    _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    await _setCurrentMediaItem();
    await play();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  // Métodos personalizados para tu app
  void updateCurrentIndex(int index) {
    _currentIndex = index;
  }

  int get currentIndex => _currentIndex;
  List<MediaItem> get currentQueue => _queue;
  AudioPlayer get player => _player;
}