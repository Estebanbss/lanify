import 'dart:io';
import 'package:flutter/material.dart';
import 'path_input_dialog.dart';

class PathNavigator extends StatelessWidget {
  final String currentPath;
  final void Function(String path) onNavigate;
  final void Function()? onNavigateParent;
  final void Function()? onCopy;

  const PathNavigator({
    super.key,
    required this.currentPath,
    required this.onNavigate,
    this.onNavigateParent,
    this.onCopy,
  });

  void _showNavigateDialog(BuildContext context) {
    TextEditingController pathController = TextEditingController(
      text: currentPath,
    );
    showDialog(
      context: context,
      builder: (context) => PathInputDialog(
        controller: pathController,
        title: 'Ir a directorio',
        label: 'Ruta del directorio',
        hint: Platform.isWindows
            ? 'C:\\Users\\Usuario\\Music'
            : Platform.isAndroid
            ? '/storage/emulated/0/Music'
            : '/home/usuario/Music',
        onSelect: () {
          Navigator.of(context).pop();
          String path = pathController.text.trim();
          if (path.isNotEmpty) onNavigate(path);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onCopy != null)
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: onCopy,
            tooltip: 'Copiar ruta',
          ),
        Expanded(
          child: GestureDetector(
            onTap: () => _showNavigateDialog(context),
            child: Text(
              currentPath,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
