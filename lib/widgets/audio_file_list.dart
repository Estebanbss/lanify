import 'package:flutter/material.dart';
import 'dart:io';

class AudioFileList extends StatelessWidget {
  final List<FileSystemEntity> audioFiles;
  final String? currentlyPlaying;
  final bool isPlaying;
  final Function(String path) onDirectoryTap;
  final Function(File file, bool isCurrentTrack) onFileTap;
  final String Function(String path) getFileName;
  final String Function(String path) getFileExtension;
  final String Function(int bytes) formatFileSize;

  const AudioFileList({
    super.key,
    required this.audioFiles,
    required this.currentlyPlaying,
    required this.isPlaying,
    required this.onDirectoryTap,
    required this.onFileTap,
    required this.getFileName,
    required this.getFileExtension,
    required this.formatFileSize,
  });

  @override
  Widget build(BuildContext context) {
    if (audioFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No se encontraron archivos de audio',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'en este directorio',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: audioFiles.length,
      itemBuilder: (context, index) {
        final entity = audioFiles[index];
        final isDirectory = entity is Directory;
        final fileName = getFileName(entity.path);
        final isCurrentTrack =
            !isDirectory &&
            currentlyPlaying != null &&
            currentlyPlaying == fileName;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          color: isCurrentTrack
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: ListTile(
            leading: Icon(
              isDirectory
                  ? Icons.folder
                  : isCurrentTrack && isPlaying
                  ? Icons.volume_up
                  : Icons.music_note,
              color: isDirectory
                  ? Colors.blue
                  : isCurrentTrack
                  ? Theme.of(context).colorScheme.primary
                  : Colors.green,
            ),
            title: Text(
              fileName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isCurrentTrack ? FontWeight.bold : null,
              ),
            ),
            subtitle: isDirectory
                ? const Text('Directorio')
                : FutureBuilder<FileStat>(
                    future: entity.stat(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text(
                          '${getFileExtension(entity.path).toUpperCase()} • ${formatFileSize(snapshot.data!.size)}',
                        );
                      }
                      return const Text('Cargando...');
                    },
                  ),
            trailing: isDirectory
                ? const Icon(Icons.chevron_right)
                : isCurrentTrack
                ? Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : const Icon(Icons.play_arrow, color: Colors.grey),
            onTap: () {
              if (isDirectory) {
                onDirectoryTap(entity.path);
              } else {
                onFileTap(entity as File, isCurrentTrack);
              }
            },
          ),
        );
      },
    );
  }
}
