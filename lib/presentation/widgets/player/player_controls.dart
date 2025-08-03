import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import '../../../features/audio_player/bloc/player_bloc.dart';
import '../../../features/audio_player/bloc/player_event.dart';
import '../../../features/audio_player/bloc/player_state.dart' as player_state;

class PlayerControls extends StatelessWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerBloc, player_state.PlayerState>(
      builder: (context, state) {
        if (state.currentMediaItem == null) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 80,
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Album art
              _buildArtwork(state),
              const SizedBox(width: 12),

              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      state.currentMediaItem!.title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      state.currentMediaItem!.artist ?? 'Artista Desconocido',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Previous button
              IconButton(
                onPressed: state.hasPrevious
                    ? () => context.read<PlayerBloc>().add(const PlayPrevious())
                    : null,
                icon: const Icon(Icons.skip_previous),
              ),

              // Play/Pause button
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

              // Next button
              IconButton(
                onPressed: state.hasNext
                    ? () => context.read<PlayerBloc>().add(const PlayNext())
                    : null,
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtwork(player_state.PlayerState state) {
    final artUri = state.currentMediaItem?.artUri;

    if (artUri != null) {
      final artworkPath = artUri.toFilePath();
      if (File(artworkPath).existsSync()) {
        return Container(
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
        );
      }
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
