import 'package:equatable/equatable.dart';
import '../../audio_explorer/models/audio_file_item.dart';

/// Estado del reproductor de audio
class PlayerState extends Equatable {
  final AudioFileItem? currentAudioFile;
  final List<AudioFileItem> playlist;
  final int currentIndex;
  final bool isPlaying;
  final bool isLoading;
  final Duration currentPosition;
  final Duration totalDuration;
  final String? error;

  const PlayerState({
    this.currentAudioFile,
    this.playlist = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.isLoading = false,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.error,
  });

  PlayerState copyWith({
    AudioFileItem? currentAudioFile,
    List<AudioFileItem>? playlist,
    int? currentIndex,
    bool? isPlaying,
    bool? isLoading,
    Duration? currentPosition,
    Duration? totalDuration,
    String? error,
  }) {
    return PlayerState(
      currentAudioFile: currentAudioFile ?? this.currentAudioFile,
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
    currentAudioFile,
    playlist,
    currentIndex,
    isPlaying,
    isLoading,
    currentPosition,
    totalDuration,
    error,
  ];
}
