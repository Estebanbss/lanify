import 'package:flutter/material.dart';

class PlayerControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final ValueChanged<Duration> onSeek;
  final Duration currentPosition;
  final Duration totalDuration;
  final String? currentlyPlaying;
  final int currentTrackIndex;
  final int playlistLength;
  final String Function(Duration) formatDuration;

  const PlayerControls({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onStop,
    required this.onNext,
    required this.onPrevious,
    required this.onSeek,
    required this.currentPosition,
    required this.totalDuration,
    required this.currentlyPlaying,
    required this.currentTrackIndex,
    required this.playlistLength,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final maxPosition = totalDuration.inMilliseconds > 0
        ? totalDuration.inMilliseconds.toDouble()
        : 1.0;
    final safePosition = currentPosition.inMilliseconds
        .clamp(0, maxPosition)
        .toDouble();

    debugPrint(
      '[PLAYER_CONTROLS] build: currentPosition=$currentPosition, totalDuration=$totalDuration',
    );

    return Column(
      children: [
        if (currentlyPlaying != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              currentlyPlaying!,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: onPrevious,
              tooltip: 'Anterior',
            ),
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: onPlayPause,
              tooltip: isPlaying ? 'Pausar' : 'Reproducir',
            ),
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: onStop,
              tooltip: 'Detener',
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: onNext,
              tooltip: 'Siguiente',
            ),
          ],
        ),
        Slider(
          value: safePosition,
          min: 0,
          max: maxPosition,
          onChanged: totalDuration.inMilliseconds == 0
              ? null
              : (value) => onSeek(Duration(milliseconds: value.toInt())),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatDuration(currentPosition)),
            Text(formatDuration(totalDuration)),
          ],
        ),
        if (playlistLength > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text('Pista ${currentTrackIndex + 1} de $playlistLength'),
          ),
      ],
    );
  }
}
