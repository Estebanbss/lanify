import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';

import '../bloc/directory_bloc.dart';
import '../bloc/directory_event.dart';
import '../models/directory_state.dart';

/// Widget de navegación de directorio con breadcrumb
class DirectoryNavigationBar extends StatelessWidget {
  const DirectoryNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DirectoryBloc, DirectoryState>(
      builder: (context, state) {
        if (state.currentPath.isEmpty) {
          return const SizedBox.shrink();
        }

        final pathParts = _getPathParts(state.currentPath);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _canNavigateUp(state.currentPath)
                    ? () => _navigateUp(context, state.currentPath)
                    : null,
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: _buildBreadcrumb(context, pathParts)),
                ),
              ),
              Text(
                '${state.directories.length} carpetas, ${state.audioFiles.length} archivos',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  List<String> _getPathParts(String path) {
    if (path.isEmpty) return [];

    final parts = path
        .split(Platform.pathSeparator)
        .where((part) => part.isNotEmpty)
        .toList();

    // En Windows, preservar la letra de unidad
    if (Platform.isWindows && parts.isNotEmpty) {
      parts[0] = parts[0] + Platform.pathSeparator;
    }

    return parts;
  }

  List<Widget> _buildBreadcrumb(BuildContext context, List<String> pathParts) {
    if (pathParts.isEmpty) return [];

    final widgets = <Widget>[];
    String currentPath = '';

    for (int i = 0; i < pathParts.length; i++) {
      final part = pathParts[i];

      if (Platform.isWindows && i == 0) {
        currentPath = part;
      } else {
        currentPath += Platform.pathSeparator + part;
      }

      final isLast = i == pathParts.length - 1;

      widgets.add(
        TextButton(
          onPressed: isLast
              ? null
              : () {
                  context.read<DirectoryBloc>().add(LoadDirectory(currentPath));
                },
          child: Text(
            part,
            style: TextStyle(
              fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
              color: isLast
                  ? Theme.of(context).textTheme.bodyLarge?.color
                  : Theme.of(context).primaryColor,
            ),
          ),
        ),
      );

      if (!isLast) {
        widgets.add(
          Icon(Icons.chevron_right, size: 16, color: Colors.grey[600]),
        );
      }
    }

    return widgets;
  }

  bool _canNavigateUp(String currentPath) {
    if (currentPath.isEmpty) return false;

    final parts = currentPath
        .split(Platform.pathSeparator)
        .where((part) => part.isNotEmpty)
        .toList();

    return parts.length > 1;
  }

  void _navigateUp(BuildContext context, String currentPath) {
    final directory = Directory(currentPath);
    final parent = directory.parent;

    if (parent.path != directory.path) {
      context.read<DirectoryBloc>().add(LoadDirectory(parent.path));
    }
  }
}
