import 'package:flutter/material.dart';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'fullscreen_image_viewer.dart';
import 'song_metadata_editor.dart';

/// Diálogo para mostrar información detallada de una canción
class SongInfoDialog extends StatefulWidget {
  final MediaItem initialMediaItem;
  final File audioFile;
  final String Function(int bytes) formatFileSize;
  final Function(MediaItem)? onMetadataUpdated;
  final Function(String, MediaItem)? onFileUpdated;

  const SongInfoDialog({
    super.key,
    required this.initialMediaItem,
    required this.audioFile,
    required this.formatFileSize,
    this.onMetadataUpdated,
    this.onFileUpdated,
  });

  @override
  State<SongInfoDialog> createState() => _SongInfoDialogState();
}

class _SongInfoDialogState extends State<SongInfoDialog> {
  late MediaItem mediaItem;

  @override
  void initState() {
    super.initState();
    mediaItem = widget.initialMediaItem;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Encabezado con carátula
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Carátula del álbum
                  if (mediaItem.artUri != null)
                    GestureDetector(
                      onTap: () {
                        showFullscreenImage(
                          context,
                          mediaItem.artUri!.toFilePath(),
                          title: mediaItem.title,
                        );
                      },
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(mediaItem.artUri!.toFilePath()),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.music_note,
                                size: 60,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        size: 60,
                        color: Colors.grey,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    mediaItem.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (mediaItem.artist != null)
                    Text(
                      mediaItem.artist!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Lista de metadatos
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildInfoRow(
                    context,
                    'Álbum',
                    mediaItem.album ?? 'Desconocido',
                    Icons.album,
                  ),
                  _buildInfoRow(
                    context,
                    'Artista',
                    mediaItem.artist ?? 'Desconocido',
                    Icons.person,
                  ),
                  const Divider(),
                  FutureBuilder<FileStat>(
                    future: widget.audioFile.stat(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final stat = snapshot.data!;
                        return Column(
                          children: [
                            _buildInfoRow(
                              context,
                              'Tamaño',
                              widget.formatFileSize(stat.size),
                              Icons.storage,
                            ),
                            _buildInfoRow(
                              context,
                              'Modificado',
                              _formatDate(stat.modified),
                              Icons.access_time,
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  _buildInfoRow(
                    context,
                    'Ruta',
                    widget.audioFile.path,
                    Icons.folder_open,
                    isPath: true,
                  ),
                  if (mediaItem.extras?['hasMetadata'] == true) ...[
                    const Divider(),
                    const Text(
                      'Metadatos',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      context,
                      'ID',
                      mediaItem.id,
                      Icons.fingerprint,
                      isPath: true,
                    ),
                  ],
                ],
              ),
            ),
            // Botones de acción
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (mediaItem.artUri != null)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        showFullscreenImage(
                          context,
                          mediaItem.artUri!.toFilePath(),
                          title: mediaItem.title,
                        );
                      },
                      icon: const Icon(Icons.zoom_in),
                      label: const Text('Ver carátula'),
                    ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showSongMetadataEditor(
                        context,
                        mediaItem,
                        widget.audioFile,
                        (updatedMediaItem) {
                          // Actualizar el mediaItem local solo si el widget sigue montado
                          if (mounted) {
                            setState(() {
                              mediaItem = updatedMediaItem;
                            });
                          }

                          // Notificar al padre con el callback simple
                          if (widget.onMetadataUpdated != null) {
                            widget.onMetadataUpdated!(updatedMediaItem);
                          }
                        },
                        onMetadataUpdated: (originalPath, updatedMediaItem) {
                          // Actualizar el mediaItem local solo si el widget sigue montado
                          if (mounted) {
                            setState(() {
                              mediaItem = updatedMediaItem;
                            });
                          }

                          // Notificar al explorador de archivos si está disponible
                          if (widget.onFileUpdated != null) {
                            widget.onFileUpdated!(
                              originalPath,
                              updatedMediaItem,
                            );
                          }
                        },
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Cerrar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    bool isPath = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: isPath ? 'monospace' : null,
                  ),
                  maxLines: isPath ? null : 2,
                  overflow: isPath ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoy ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} días atrás';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Función auxiliar para mostrar el diálogo de información de la canción
void showSongInfoDialog(
  BuildContext context,
  MediaItem mediaItem,
  File audioFile,
  String Function(int bytes) formatFileSize, {
  Function(MediaItem)? onMetadataUpdated,
  Function(String, MediaItem)? onFileUpdated,
}) {
  showDialog(
    context: context,
    builder: (context) => SongInfoDialog(
      initialMediaItem: mediaItem,
      audioFile: audioFile,
      formatFileSize: formatFileSize,
      onMetadataUpdated: onMetadataUpdated,
      onFileUpdated: onFileUpdated,
    ),
  );
}
