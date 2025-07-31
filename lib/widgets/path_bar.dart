import 'package:flutter/material.dart';

class PathBar extends StatelessWidget {
  final String currentPath;
  final VoidCallback onCopy;

  const PathBar({super.key, required this.currentPath, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8.0),
      color: Colors.grey[200],
      child: Row(
        children: [
          const Icon(Icons.folder, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              currentPath,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.content_copy, size: 16),
            onPressed: onCopy,
            tooltip: 'Copiar ruta',
          ),
        ],
      ),
    );
  }
}
