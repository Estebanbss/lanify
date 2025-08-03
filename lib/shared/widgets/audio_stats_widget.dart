import 'package:flutter/material.dart';
import '../../features/audio_explorer/models/audio_file_item.dart';
import '../../core/utils/file_utils.dart';

/// Widget que muestra estadísticas de una colección de archivos de audio
class AudioStatsWidget extends StatelessWidget {
  final List<AudioFileItem> audioFiles;

  const AudioStatsWidget({super.key, required this.audioFiles});

  @override
  Widget build(BuildContext context) {
    if (audioFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    final stats = _calculateStats();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildStatRow('Total de canciones:', '${audioFiles.length}'),
            _buildStatRow('Duración total:', stats.totalDuration),
            _buildStatRow('Artistas únicos:', '${stats.uniqueArtists}'),
            _buildStatRow('Álbumes únicos:', '${stats.uniqueAlbums}'),
            if (stats.totalSize > 0)
              _buildStatRow('Tamaño total:', stats.totalSizeFormatted),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  _AudioStats _calculateStats() {
    var totalDuration = Duration.zero;
    var totalSize = 0;
    final artists = <String>{};
    final albums = <String>{};

    for (final file in audioFiles) {
      totalDuration += file.duration;

      if (file.metadata?.extras?['fileSize'] != null) {
        totalSize += file.metadata!.extras!['fileSize'] as int;
      }

      if (file.artist != 'Unknown Artist') {
        artists.add(file.artist);
      }

      if (file.album != 'Unknown Album') {
        albums.add(file.album);
      }
    }

    return _AudioStats(
      totalDuration: DurationUtils.formatDuration(totalDuration),
      uniqueArtists: artists.length,
      uniqueAlbums: albums.length,
      totalSize: totalSize,
      totalSizeFormatted: FileUtils.formatFileSize(totalSize),
    );
  }
}

class _AudioStats {
  final String totalDuration;
  final int uniqueArtists;
  final int uniqueAlbums;
  final int totalSize;
  final String totalSizeFormatted;

  _AudioStats({
    required this.totalDuration,
    required this.uniqueArtists,
    required this.uniqueAlbums,
    required this.totalSize,
    required this.totalSizeFormatted,
  });
}
