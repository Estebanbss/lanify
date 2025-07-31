import 'package:flutter/material.dart';

class FileDirectoryCounter extends StatelessWidget {
  final int audioFileCount;
  final int directoryCount;

  const FileDirectoryCounter({
    super.key,
    required this.audioFileCount,
    required this.directoryCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Archivos de audio: $audioFileCount',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Directorios: $directoryCount',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
