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

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentlyPlaying != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.music_note,
                      color: Colors.deepPurple,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        currentlyPlaying!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.skip_previous,
                    size: 32,
                    color: Colors.blueGrey,
                  ),
                  onPressed: onPrevious,
                  tooltip: 'Anterior',
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isPlaying ? Colors.deepPurple : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 36,
                      color: isPlaying ? Colors.white : Colors.deepPurple,
                    ),
                    onPressed: onPlayPause,
                    tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.stop,
                    size: 32,
                    color: Colors.redAccent,
                  ),
                  onPressed: onStop,
                  tooltip: 'Detener',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.skip_next,
                    size: 32,
                    color: Colors.blueGrey,
                  ),
                  onPressed: onNext,
                  tooltip: 'Siguiente',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Text(
                    formatDuration(currentPosition),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  Expanded(
                    child: Slider(
                      value: safePosition,
                      min: 0,
                      max: maxPosition,
                      activeColor: Colors.deepPurple,
                      inactiveColor: Colors.deepPurple.shade100,
                      onChanged: totalDuration.inMilliseconds == 0
                          ? null
                          : (value) =>
                                onSeek(Duration(milliseconds: value.toInt())),
                    ),
                  ),
                  Text(
                    formatDuration(totalDuration),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            if (playlistLength > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Pista ${currentTrackIndex + 1} de $playlistLength',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
