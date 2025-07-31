import 'package:flutter/material.dart';
import 'dart:io';

class AudioFileList extends StatefulWidget {
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
  State<AudioFileList> createState() => _AudioFileListState();
}

class _AudioFileListState extends State<AudioFileList> {
  late TextEditingController _searchController;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() {
        _filter = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFiles = _filter.isEmpty
        ? widget.audioFiles
        : widget.audioFiles.where((entity) {
            final name = widget.getFileName(entity.path).toLowerCase();
            return name.contains(_filter);
          }).toList();

    if (widget.audioFiles.isEmpty) {
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Buscar archivo o carpeta...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 12,
              ),
              suffixIcon: _filter.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: filteredFiles.isEmpty
              ? Center(
                  child: Text(
                    'No hay resultados',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredFiles.length,
                  itemBuilder: (context, index) {
                    final entity = filteredFiles[index];
                    final isDirectory = entity is Directory;
                    final fileName = widget.getFileName(entity.path);
                    final isCurrentTrack =
                        !isDirectory &&
                        widget.currentlyPlaying != null &&
                        widget.currentlyPlaying == fileName;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      color: isCurrentTrack
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        leading: Icon(
                          isDirectory
                              ? Icons.folder
                              : isCurrentTrack && widget.isPlaying
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
                                      '${widget.getFileExtension(entity.path).toUpperCase()} • ${widget.formatFileSize(snapshot.data!.size)}',
                                    );
                                  }
                                  return const Text('Cargando...');
                                },
                              ),
                        trailing: isDirectory
                            ? const Icon(Icons.chevron_right)
                            : isCurrentTrack
                            ? Icon(
                                widget.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : const Icon(Icons.play_arrow, color: Colors.grey),
                        onTap: () {
                          if (isDirectory) {
                            widget.onDirectoryTap(entity.path);
                          } else {
                            widget.onFileTap(entity as File, isCurrentTrack);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
