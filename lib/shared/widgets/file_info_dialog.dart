import 'package:flutter/material.dart';
import 'package:lanify/shared/widgets/show_image.dart';
import 'dart:io';
import '../../core/utils/file_utils.dart';

/// Widget reutilizable para mostrar información de archivos
class FileInfoDialog extends StatelessWidget {
  final String title;
  final String artist;
  final String album;
  final String fileName;
  final Duration? duration;
  final int? fileSize;
  final String? artworkPath;
  final Map<String, dynamic>? extras;

  const FileInfoDialog({
    super.key,
    required this.title,
    required this.artist,
    required this.album,
    required this.fileName,
    this.duration,
    this.fileSize,
    this.artworkPath,
    this.extras,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          const SizedBox(width: 8),
          const Text('Información del archivo'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen con borde y sombra
            Center(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      barrierDismissible: true,
                      context: context,
                      builder: (context) =>
                          ShowImage(image: artworkPath ?? fileName),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: Colors.blue.shade100, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: (artworkPath != null && artworkPath!.isNotEmpty)
                          ? Image.file(
                              File(artworkPath!),
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, size: 48),
                            )
                          : Image.file(
                              File(fileName),
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, size: 48),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            // Info principal
            _buildInfoRow('Título', title, bold: true),
            _buildInfoRow('Artista', artist),
            _buildInfoRow('Álbum', album),
            if (duration != null && duration! > Duration.zero)
              _buildInfoRow(
                'Duración',
                DurationUtils.formatDuration(duration!),
              ),
            if (fileSize != null)
              _buildInfoRow('Tamaño', FileUtils.formatFileSize(fileSize!)),
            _buildInfoRow('Archivo', fileName),
            // Metadatos extra
            if (extras != null && extras!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Metadata extra:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      ...extras!.entries.map(
                        (entry) => _buildInfoRow(
                          entry.key,
                          entry.value?.toString() ?? '',
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          label: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool bold = false,
    double fontSize = 14,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                fontSize: fontSize,
                color: bold
                    ? Colors.blue.shade700
                    : const Color.fromARGB(221, 73, 72, 72),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Desconocido',
              style: TextStyle(fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }
}
