import 'package:flutter/material.dart';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'audio_metadata_loader.dart';
import 'package:palette_generator/palette_generator.dart';
import 'fullscreen_image_viewer.dart';
import 'song_info_dialog.dart';
import 'reactive_file_manager.dart';

class AudioFileList extends StatefulWidget {
  final List<FileSystemEntity> audioFiles;
  final String? currentlyPlaying;
  final bool isPlaying;
  final Function(String path) onDirectoryTap;
  final Function(File file, bool isCurrentTrack) onFileTap;
  final String Function(String path) getFileName;
  final String Function(String path) getFileExtension;
  final String Function(int bytes) formatFileSize;
  final void Function(Color?)? onDominantColorChanged;
  final void Function(String filePath, MediaItem updatedMediaItem)?
  onMetadataUpdated;

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
    this.onDominantColorChanged,
    this.onMetadataUpdated,
  });

  @override
  State<AudioFileList> createState() => _AudioFileListState();
}

class _AudioFileListState extends State<AudioFileList> {
  final ReactiveFileManager _fileManager = ReactiveFileManager();
  late TextEditingController _searchController;
  String _filter = '';
  bool _isGroupedByArtist = false;

  Future<Color?> getDominantColor(String artUri) async {
    // Usar el reactive file manager
    final cachedColor = _fileManager.getDominantColor(artUri);
    if (cachedColor != null) {
      return cachedColor;
    }

    try {
      final file = File(artUri);

      // Verificar que el archivo existe y no está vacío
      if (!await file.exists() || await file.length() == 0) {
        _fileManager.updateDominantColor(artUri, null);
        return null;
      }

      // Usar timeout para evitar bloqueos
      final palette = await PaletteGenerator.fromImageProvider(
        FileImage(file),
        size: const Size(40, 40),
      ).timeout(const Duration(seconds: 3));

      final color = palette.dominantColor?.color;
      _fileManager.updateDominantColor(artUri, color);
      return color;
    } catch (e) {
      debugPrint('Error al obtener color dominante: $e');
      _fileManager.updateDominantColor(artUri, null);
      return null;
    }
  }

  /// Invalidar caches para un archivo específico
  void _invalidateCachesForFile(String filePath, MediaItem updatedMediaItem) {
    final oldPath = updatedMediaItem.extras?['originalPath'] ?? filePath;
    final newPath = updatedMediaItem.extras?['newPath'] ?? filePath;

    debugPrint(
      'AudioFileList._invalidateCachesForFile: oldPath=$oldPath, newPath=$newPath',
    );

    // Usar el reactive file manager
    if (oldPath != newPath) {
      _fileManager.handleFileRenamed(oldPath, newPath, updatedMediaItem);
    } else {
      _fileManager.updateMetadata(newPath, updatedMediaItem);
    }
  }

  /// Widget optimizado para mostrar archivos agrupados por artista
  Widget _buildGroupedView(List<FileSystemEntity> filteredFiles) {
    // Separar directorios y archivos
    final directories = filteredFiles.where((f) => f is Directory).toList();
    final audioFiles = filteredFiles.where((f) => f is File).toList();

    return ListView.builder(
      itemCount: directories.length + audioFiles.length,
      itemBuilder: (context, index) {
        // Mostrar directorios primero
        if (index < directories.length) {
          final entity = directories[index];
          final fileName = widget.getFileName(entity.path);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              leading: const Icon(Icons.folder, color: Colors.blue),
              title: Text(fileName, overflow: TextOverflow.ellipsis),
              subtitle: const Text('Directorio'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => widget.onDirectoryTap(entity.path),
            ),
          );
        }

        // Mostrar archivos de audio
        final audioIndex = index - directories.length;
        final entity = audioFiles[audioIndex] as File;
        final fileName = widget.getFileName(entity.path);
        final isCurrentTrack = widget.currentlyPlaying == fileName;

        return _buildAudioFileTileWithArtist(entity, fileName, isCurrentTrack);
      },
    );
  }

  /// Construir tile de audio con información de artista (sin bloquear UI)
  Widget _buildAudioFileTileWithArtist(
    File entity,
    String fileName,
    bool isCurrentTrack,
  ) {
    return FutureBuilder<MediaItem>(
      future:
          _fileManager.getMetadataFuture(entity.path) ??
          AudioMetadataLoader.extractMetadataForFile(entity),
      builder: (context, snapshot) {
        String artistInfo = '';

        if (snapshot.hasData &&
            snapshot.data?.artist?.trim().isNotEmpty == true) {
          artistInfo = ' • ${snapshot.data!.artist!}';
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          artistInfo = ' • Cargando...';
        } else {
          artistInfo = ' • Artista Desconocido';
        }

        final filePath = entity.path;
        Future<MediaItem>? metadataFuture = _fileManager.getMetadataFuture(
          filePath,
        );

        if (metadataFuture == null) {
          metadataFuture = AudioMetadataLoader.extractMetadataForFile(entity);
          _fileManager.updateMetadataFuture(filePath, metadataFuture);
        }

        Widget leadingWidget = FutureBuilder(
          future: metadataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError) {
                return Icon(
                  isCurrentTrack && widget.isPlaying
                      ? Icons.volume_up
                      : Icons.music_note,
                  color: isCurrentTrack
                      ? Theme.of(context).colorScheme.primary
                      : Colors.green,
                );
              }

              if (snapshot.hasData &&
                  snapshot.data != null &&
                  snapshot.data?.artUri != null) {
                try {
                  return GestureDetector(
                    onTap: () {
                      showFullscreenImage(
                        context,
                        snapshot.data!.artUri!.toFilePath(),
                        title: widget.getFileName(entity.path),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(snapshot.data!.artUri!.toFilePath()),
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Icon(
                          isCurrentTrack && widget.isPlaying
                              ? Icons.volume_up
                              : Icons.music_note,
                          color: isCurrentTrack
                              ? Theme.of(context).colorScheme.primary
                              : Colors.green,
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  return Icon(
                    isCurrentTrack && widget.isPlaying
                        ? Icons.volume_up
                        : Icons.music_note,
                    color: isCurrentTrack
                        ? Theme.of(context).colorScheme.primary
                        : Colors.green,
                  );
                }
              }
            }

            return Icon(
              isCurrentTrack && widget.isPlaying
                  ? Icons.volume_up
                  : Icons.music_note,
              color: isCurrentTrack
                  ? Theme.of(context).colorScheme.primary
                  : Colors.green,
            );
          },
        );

        Widget cardChild = ListTile(
          leading: leadingWidget,
          title: Text(
            fileName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isCurrentTrack ? FontWeight.bold : null,
            ),
          ),
          subtitle: FutureBuilder<FileStat>(
            future: entity.stat(),
            builder: (context, statSnapshot) {
              if (statSnapshot.hasData) {
                return Text(
                  '${widget.getFileExtension(entity.path).toUpperCase()} • ${widget.formatFileSize(statSnapshot.data!.size)}$artistInfo',
                );
              }
              return Text('Cargando...$artistInfo');
            },
          ),
          trailing: isCurrentTrack
              ? Icon(
                  widget.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Theme.of(context).colorScheme.primary,
                )
              : const Icon(Icons.play_arrow, color: Colors.grey),
          onTap: () => widget.onFileTap(entity, isCurrentTrack),
          onLongPress: () {
            final future = _fileManager.getMetadataFuture(entity.path);
            if (future != null) {
              future.then((mediaItem) {
                if (context.mounted) {
                  showSongInfoDialog(
                    context,
                    mediaItem,
                    entity,
                    widget.formatFileSize,
                    onMetadataUpdated: (updatedMediaItem) {
                      _invalidateCachesForFile(entity.path, updatedMediaItem);
                      if (widget.onMetadataUpdated != null) {
                        widget.onMetadataUpdated!(
                          entity.path,
                          updatedMediaItem,
                        );
                      }
                      if (mounted) setState(() {});
                    },
                    onFileUpdated: (originalPath, updatedMediaItem) {
                      _invalidateCachesForFile(originalPath, updatedMediaItem);
                      final newPath = updatedMediaItem.id;
                      if (newPath != originalPath) {
                        _invalidateCachesForFile(
                          originalPath,
                          updatedMediaItem,
                        );
                      }
                      if (widget.onMetadataUpdated != null) {
                        widget.onMetadataUpdated!(
                          originalPath,
                          updatedMediaItem,
                        );
                      }
                      if (mounted) setState(() {});
                    },
                  );
                }
              });
            }
          },
        );

        if (isCurrentTrack) {
          return FutureBuilder(
            future: _fileManager.getMetadataFuture(entity.path),
            builder: (context, snapshot) {
              final artUri =
                  (snapshot.hasData &&
                      snapshot.data != null &&
                      snapshot.data?.artUri != null)
                  ? snapshot.data?.artUri?.toFilePath()
                  : null;
              if (artUri != null) {
                return FutureBuilder<Color?>(
                  future: getDominantColor(artUri),
                  builder: (context, colorSnap) {
                    final domColor =
                        colorSnap.data?.withValues(alpha: 0.55) ??
                        Theme.of(context).colorScheme.primaryContainer;
                    if (widget.onDominantColorChanged != null &&
                        colorSnap.data != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        widget.onDominantColorChanged!(colorSnap.data);
                      });
                    }
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      color: domColor,
                      child: cardChild,
                    );
                  },
                );
              } else {
                if (widget.onDominantColorChanged != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    widget.onDominantColorChanged!(null);
                  });
                }
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: cardChild,
                );
              }
            },
          );
        } else {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: cardChild,
          );
        }
      },
    );
  }

  /// Construir un tile para archivo de audio (usado en ambos modos de vista)
  Widget _buildAudioFileTile(
    File entity,
    String fileName,
    bool isCurrentTrack,
  ) {
    final filePath = entity.path;

    // Usar el reactive file manager
    Future<MediaItem>? metadataFuture = _fileManager.getMetadataFuture(
      filePath,
    );

    if (metadataFuture == null) {
      metadataFuture = AudioMetadataLoader.extractMetadataForFile(entity);
      _fileManager.updateMetadataFuture(filePath, metadataFuture);
    }

    Widget leadingWidget = FutureBuilder(
      future: metadataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            // Error al cargar metadata
            return Icon(
              isCurrentTrack && widget.isPlaying
                  ? Icons.volume_up
                  : Icons.music_note,
              color: isCurrentTrack
                  ? Theme.of(context).colorScheme.primary
                  : Colors.green,
            );
          }

          if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data?.artUri != null) {
            try {
              return GestureDetector(
                onTap: () {
                  // Mostrar imagen en pantalla completa
                  showFullscreenImage(
                    context,
                    snapshot.data!.artUri!.toFilePath(),
                    title: widget.getFileName(entity.path),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    File(snapshot.data!.artUri!.toFilePath()),
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Icon(
                      isCurrentTrack && widget.isPlaying
                          ? Icons.volume_up
                          : Icons.music_note,
                      color: isCurrentTrack
                          ? Theme.of(context).colorScheme.primary
                          : Colors.green,
                    ),
                  ),
                ),
              );
            } catch (e) {
              // Error al mostrar imagen
              return Icon(
                isCurrentTrack && widget.isPlaying
                    ? Icons.volume_up
                    : Icons.music_note,
                color: isCurrentTrack
                    ? Theme.of(context).colorScheme.primary
                    : Colors.green,
              );
            }
          }
        }

        // Cargando o sin artwork
        return Icon(
          isCurrentTrack && widget.isPlaying
              ? Icons.volume_up
              : Icons.music_note,
          color: isCurrentTrack
              ? Theme.of(context).colorScheme.primary
              : Colors.green,
        );
      },
    );

    Widget cardChild = ListTile(
      leading: leadingWidget,
      title: Text(
        fileName,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: isCurrentTrack ? FontWeight.bold : null),
      ),
      subtitle: FutureBuilder<FileStat>(
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
      trailing: isCurrentTrack
          ? Icon(
              widget.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Theme.of(context).colorScheme.primary,
            )
          : const Icon(Icons.play_arrow, color: Colors.grey),
      onTap: () => widget.onFileTap(entity, isCurrentTrack),
      onLongPress: () {
        // Mostrar información detallada de la canción
        final future = _fileManager.getMetadataFuture(entity.path);
        if (future != null) {
          future.then((mediaItem) {
            if (context.mounted) {
              showSongInfoDialog(
                context,
                mediaItem,
                entity,
                widget.formatFileSize,
                onMetadataUpdated: (updatedMediaItem) {
                  _invalidateCachesForFile(entity.path, updatedMediaItem);
                  if (widget.onMetadataUpdated != null) {
                    widget.onMetadataUpdated!(entity.path, updatedMediaItem);
                  }
                  if (mounted) setState(() {});
                },
                onFileUpdated: (originalPath, updatedMediaItem) {
                  _invalidateCachesForFile(originalPath, updatedMediaItem);
                  final newPath = updatedMediaItem.id;
                  if (newPath != originalPath) {
                    _invalidateCachesForFile(originalPath, updatedMediaItem);
                  }
                  if (widget.onMetadataUpdated != null) {
                    widget.onMetadataUpdated!(originalPath, updatedMediaItem);
                  }
                  if (mounted) setState(() {});
                },
              );
            }
          });
        }
      },
    );

    if (isCurrentTrack) {
      // Si hay carátula, usar color dominante
      return FutureBuilder(
        future: _fileManager.getMetadataFuture(entity.path),
        builder: (context, snapshot) {
          final artUri =
              (snapshot.hasData &&
                  snapshot.data != null &&
                  snapshot.data?.artUri != null)
              ? snapshot.data?.artUri?.toFilePath()
              : null;
          if (artUri != null) {
            return FutureBuilder<Color?>(
              future: getDominantColor(artUri),
              builder: (context, colorSnap) {
                final domColor =
                    colorSnap.data?.withValues(alpha: 0.55) ??
                    Theme.of(context).colorScheme.primaryContainer;
                // Notificar al padre solo si hay color
                if (widget.onDominantColorChanged != null &&
                    colorSnap.data != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    widget.onDominantColorChanged!(colorSnap.data);
                  });
                }
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  color: domColor,
                  child: cardChild,
                );
              },
            );
          } else {
            // Si no hay carátula, notificar null
            if (widget.onDominantColorChanged != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onDominantColorChanged!(null);
              });
            }
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: cardChild,
            );
          }
        },
      );
    } else {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: cardChild,
      );
    }
  }

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
          child: Row(
            children: [
              // Buscador
              Expanded(
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
              const SizedBox(width: 8),
              // Botón cambiador de vista
              IconButton(
                onPressed: () {
                  setState(() {
                    _isGroupedByArtist = !_isGroupedByArtist;
                  });
                },
                icon: Icon(
                  _isGroupedByArtist ? Icons.list : Icons.group,
                  color: Theme.of(context).colorScheme.primary,
                ),
                tooltip: _isGroupedByArtist
                    ? 'Vista de archivos'
                    : 'Agrupar por artista',
                style: IconButton.styleFrom(
                  backgroundColor: _isGroupedByArtist
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                ),
              ),
            ],
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
              : _isGroupedByArtist
              ? _buildGroupedView(filteredFiles)
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

                    if (isDirectory) {
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.folder, color: Colors.blue),
                          title: Text(
                            fileName,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: const Text('Directorio'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => widget.onDirectoryTap(entity.path),
                        ),
                      );
                    } else {
                      return _buildAudioFileTile(
                        entity as File,
                        fileName,
                        isCurrentTrack,
                      );
                    }
                  },
                ),
        ),
      ],
    );
  }
}
