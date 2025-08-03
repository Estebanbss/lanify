import 'package:equatable/equatable.dart';
import 'package:audio_service/audio_service.dart';

/// Estado del reproductor de audio
class PlayerState extends Equatable {
  final MediaItem? currentMediaItem;
  final List<MediaItem> playlist;
  final int currentIndex;
  final bool isPlaying;
  final bool isLoading;
  final Duration currentPosition;
  final Duration totalDuration;
  final String? error;

  const PlayerState({
    this.currentMediaItem,
    this.playlist = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.isLoading = false,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.error,
  });

  PlayerState copyWith({
    MediaItem? currentMediaItem,
    List<MediaItem>? playlist,
    int? currentIndex,
    bool? isPlaying,
    bool? isLoading,
    Duration? currentPosition,
    Duration? totalDuration,
    String? error,
  }) {
    return PlayerState(
      currentMediaItem: currentMediaItem ?? this.currentMediaItem,
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      error: error,
    );
  }

  bool get hasNext => currentIndex < playlist.length - 1;
  bool get hasPrevious => currentIndex > 0;
  bool get hasPlaylist => playlist.isNotEmpty;

  @override
  List<Object?> get props => [
    currentMediaItem,
    playlist,
    currentIndex,
    isPlaying,
    isLoading,
    currentPosition,
    totalDuration,
    error,
  ];
}
