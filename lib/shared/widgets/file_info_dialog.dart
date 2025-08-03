import 'package:flutter/material.dart';
import '../../core/utils/file_utils.dart';

/// Widget reutilizable para mostrar información de archivos
class FileInfoDialog extends StatelessWidget {
  final String title;
  final String artist;
  final String album;
  final String fileName;
  final Duration? duration;
  final int? fileSize;

  const FileInfoDialog({
    super.key,
    required this.title,
    required this.artist,
    required this.album,
    required this.fileName,
    this.duration,
    this.fileSize,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Información del archivo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Título', title),
          _buildInfoRow('Artista', artist),
          _buildInfoRow('Álbum', album),
          if (duration != null && duration! > Duration.zero)
            _buildInfoRow('Duración', DurationUtils.formatDuration(duration!)),
          if (fileSize != null)
            _buildInfoRow('Tamaño', FileUtils.formatFileSize(fileSize!)),
          _buildInfoRow('Archivo', fileName),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value.isNotEmpty ? value : 'Desconocido')),
        ],
      ),
    );
  }
}
