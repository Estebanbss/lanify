import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lanify/shared/widgets/show_image.dart';
import 'dart:io';
import '../../../features/audio_player/bloc/player_bloc.dart';
import '../../../features/audio_player/bloc/player_event.dart';
import '../../../features/audio_player/bloc/player_state.dart' as player_state;

class PlayerControls extends StatelessWidget {
  const PlayerControls({super.key});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerBloc, player_state.PlayerState>(
      builder: (context, state) {
        if (state.currentAudioFile == null) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            children: [
              // Duration slider row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Current position
                        Text(
                          _formatDuration(state.currentPosition),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        // Slider
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                            ),
                            child: Slider(
                              value: state.totalDuration.inMilliseconds > 0
                                  ? state.currentPosition.inMilliseconds
                                        .toDouble()
                                        .clamp(
                                          0.0,
                                          state.totalDuration.inMilliseconds
                                              .toDouble(),
                                        )
                                  : 0.0,
                              min: 0,
                              max: state.totalDuration.inMilliseconds > 0
                                  ? state.totalDuration.inMilliseconds
                                        .toDouble()
                                  : 1.0,
                              onChanged: state.totalDuration.inMilliseconds > 0
                                  ? (value) {
                                      final position = Duration(
                                        milliseconds: value.round(),
                                      );
                                      context.read<PlayerBloc>().add(
                                        SeekTo(position),
                                      );
                                    }
                                  : null,
                            ),
                          ),
                        ),
                        // Total duration
                        Text(
                          _formatDuration(state.totalDuration),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Row(
                children: [
                  // Album art
                  _buildArtwork(context, state),
                  const SizedBox(width: 12),
                  // Track info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.currentAudioFile!.title,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          state.currentAudioFile!.artist,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Playback controls
                  IconButton(
                    onPressed: state.hasPrevious
                        ? () => context.read<PlayerBloc>().add(
                            const PlayPrevious(),
                          )
                        : null,
                    icon: const Icon(Icons.skip_previous),
                  ),
                  if (state.isLoading)
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      onPressed: () {
                        context.read<PlayerBloc>().add(const TogglePlayPause());
                      },
                      icon: Icon(
                        state.isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 32,
                      ),
                    ),
                  IconButton(
                    onPressed: state.hasNext
                        ? () => context.read<PlayerBloc>().add(const PlayNext())
                        : null,
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtwork(BuildContext context, player_state.PlayerState state) {
    final artworkPath = state.currentAudioFile?.effectiveArtworkPath;

    if (artworkPath != null &&
        artworkPath.isNotEmpty &&
        File(artworkPath).existsSync()) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => ShowImage(image: artworkPath),
            );
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(artworkPath),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[300],
                    ),
                    child: const Icon(Icons.music_note, size: 30),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    // Fallback al contenedor con ícono
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[300],
      ),
      child: const Icon(Icons.music_note, size: 30),
    );
  }
}
