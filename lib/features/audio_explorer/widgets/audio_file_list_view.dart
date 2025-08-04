import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lanify/shared/widgets/show_image.dart';
import 'dart:io';

import '../bloc/directory_bloc.dart';
import '../bloc/directory_event.dart';
import '../models/directory_state.dart';
import '../models/audio_file_item.dart';
import '../../audio_player/bloc/player_bloc.dart';
import '../../audio_player/bloc/player_event.dart';
import '../../audio_player/bloc/player_state.dart' as player_state;
import '../../../core/utils/file_utils.dart';
import '../../../shared/widgets/file_info_dialog.dart';

/// Vista de lista de archivos de audio y directorios
class AudioFileListView extends StatelessWidget {
  const AudioFileListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DirectoryBloc, DirectoryState>(
      builder: (context, state) {
        final filteredDirectories = state.filteredDirectories;
        final filteredAudioFiles = state.filteredAudioFiles;

        if (filteredDirectories.isEmpty && filteredAudioFiles.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No se encontraron archivos de audio',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        if (state.isGroupedByArtist) {
          return _buildGroupedView(context, state);
        } else {
          return _buildListView(
            context,
            filteredDirectories,
            filteredAudioFiles,
          );
        }
      },
    );
  }

  Widget _buildListView(
    BuildContext context,
    List<Directory> directories,
    List<AudioFileItem> audioFiles,
  ) {
    final totalItems = directories.length + audioFiles.length;

    return ListView.builder(
      itemCount: totalItems,
      itemBuilder: (context, index) {
        if (index < directories.length) {
          // Mostrar directorio
          final directory = directories[index];
          return _buildDirectoryTile(context, directory);
        } else {
          // Mostrar archivo de audio
          final audioIndex = index - directories.length;
          final audioFile = audioFiles[audioIndex];
          return _buildAudioFileTile(context, audioFile, audioFiles);
        }
      },
    );
  }

  Widget _buildGroupedView(BuildContext context, DirectoryState state) {
    final groupedFiles = state.groupedByArtist;

    return ListView.builder(
      itemCount: state.filteredDirectories.length + groupedFiles.length,
      itemBuilder: (context, index) {
        if (index < state.filteredDirectories.length) {
          // Mostrar directorio
          final directory = state.filteredDirectories[index];
          return _buildDirectoryTile(context, directory);
        } else {
          // Mostrar grupo de artista
          final groupIndex = index - state.filteredDirectories.length;
          final entry = groupedFiles.entries.toList()[groupIndex];
          final artist = entry.key;
          final files = entry.value;

          return ExpansionTile(
            leading: const Icon(Icons.person),
            title: Text(artist),
            subtitle: Text('${files.length} canciones'),
            children: files
                .map(
                  (file) => _buildAudioFileTile(
                    context,
                    file,
                    state.filteredAudioFiles,
                  ),
                )
                .toList(),
          );
        }
      },
    );
  }

  Widget _buildDirectoryTile(BuildContext context, Directory directory) {
    final name = directory.path.split(Platform.pathSeparator).last;

    return ListTile(
      leading: const Icon(Icons.folder, color: Colors.amber),
      title: Text(name),
      onTap: () {
        context.read<DirectoryBloc>().add(LoadDirectory(directory.path));
      },
    );
  }

  Widget _buildAudioFileTile(
    BuildContext context,
    AudioFileItem audioFile,
    List<AudioFileItem> playlist,
  ) {
    return BlocBuilder<PlayerBloc, player_state.PlayerState>(
      builder: (context, playerState) {
        final isCurrentlyPlaying =
            playerState.currentMediaItem?.id == audioFile.file.path;
        final isLoading = isCurrentlyPlaying && playerState.isLoading;

        return ListTile(
          leading: _buildLeadingIcon(
            context,
            isCurrentlyPlaying,
            isLoading,
            playerState.isPlaying,
            audioFile,
          ),
          title: Text(
            audioFile.title,
            style: TextStyle(
              fontWeight: isCurrentlyPlaying
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(audioFile.artist),
              if (audioFile.album.isNotEmpty)
                Text(
                  audioFile.album,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (audioFile.duration > Duration.zero)
                Text(
                  DurationUtils.formatDuration(audioFile.duration),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showAudioFileMenu(context, audioFile),
              ),
            ],
          ),
          onTap: () => _playAudio(context, audioFile, playlist),
        );
      },
    );
  }

  Widget _buildLeadingIcon(
    BuildContext context,
    bool isCurrentlyPlaying,
    bool isLoading,
    bool isPlaying,
    AudioFileItem audioFile,
  ) {
    if (isLoading) {
      return const SizedBox(
        width: 56,
        height: 56,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Construir el contenido del leading icon
    Widget iconContent;

    if (isCurrentlyPlaying) {
      iconContent = Icon(
        isPlaying ? Icons.pause : Icons.play_arrow,
        color: Colors.white,
        size: 28,
      );
    } else {
      iconContent = const Icon(Icons.music_note, size: 28);
    }

    // Si hay carátula disponible, mostrarla como fondo
    if (audioFile.effectiveArtworkPath != null &&
        audioFile.effectiveArtworkPath!.isNotEmpty &&
        File(audioFile.effectiveArtworkPath!).existsSync()) {
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) =>
                ShowImage(image: audioFile.effectiveArtworkPath),
          );
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                // Imagen de fondo
                Image.file(
                  File(audioFile.effectiveArtworkPath!),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Si hay error cargando la imagen, mostrar ícono por defecto
                    return Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey[300],
                      child: const Icon(Icons.music_note, color: Colors.grey),
                    );
                  },
                ),
                // Overlay para controles de reproducción
                if (isCurrentlyPlaying)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(child: iconContent),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Si no hay carátula, mostrar contenedor con ícono
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isCurrentlyPlaying
            ? Colors.blue.withAlpha(25)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: isCurrentlyPlaying
            ? Border.all(color: Colors.blue, width: 2)
            : null,
      ),
      child: Center(
        child: Icon(
          isCurrentlyPlaying
              ? (isPlaying ? Icons.pause : Icons.play_arrow)
              : Icons.music_note,
          color: isCurrentlyPlaying ? Colors.blue : Colors.grey[600],
          size: 28,
        ),
      ),
    );
  }
}

void _playAudio(
  BuildContext context,
  AudioFileItem audioFile,
  List<AudioFileItem> playlist,
) {
  // Convertir a MediaItems para el player
  final mediaItems = playlist.map((file) => file.toMediaItem()).toList();
  final mediaItem = audioFile.toMediaItem();

  context.read<PlayerBloc>().add(
    PlayAudio(mediaItem: mediaItem, playlist: mediaItems),
  );

  // Actualizar el estado en DirectoryBloc
  context.read<DirectoryBloc>().add(SetCurrentlyPlaying(audioFile.file.path));
}

void _showAudioFileMenu(BuildContext context, AudioFileItem audioFile) {
  showModalBottomSheet(
    context: context,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('Información del archivo'),
          onTap: () {
            Navigator.pop(context);
            _showFileInfo(context, audioFile);
          },
        ),
        ListTile(
          leading: const Icon(Icons.folder),
          title: const Text('Mostrar en carpeta'),
          onTap: () {
            Navigator.pop(context);
            _showInFolder(context, audioFile);
          },
        ),
      ],
    ),
  );
}

void _showFileInfo(BuildContext context, AudioFileItem audioFile) {
  showDialog(
    context: context,
    builder: (context) => FileInfoDialog(
      title: audioFile.title,
      artist: audioFile.artist,
      album: audioFile.album,
      fileName: audioFile.fileName,
      duration: audioFile.duration,
      fileSize: audioFile.metadata?.extras?['fileSize'] as int?,
      artworkPath: audioFile.effectiveArtworkPath,
      extras: audioFile.metadata?.extras,
    ),
  );
}

void _showInFolder(BuildContext context, AudioFileItem audioFile) {
  final directory = audioFile.file.parent;
  context.read<DirectoryBloc>().add(LoadDirectory(directory.path));

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Navegando a: ${directory.path}'),
      duration: const Duration(seconds: 2),
    ),
  );
}
