import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';

import '../bloc/directory_bloc.dart';
import '../bloc/directory_event.dart';
import '../models/directory_state.dart';

/// Widget de navegación de directorio con breadcrumb
class DirectoryNavigationBar extends StatefulWidget {
  const DirectoryNavigationBar({super.key});

  @override
  State<DirectoryNavigationBar> createState() => _DirectoryNavigationBarState();
}

class _DirectoryNavigationBarState extends State<DirectoryNavigationBar> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DirectoryBloc, DirectoryState>(
      listenWhen: (previous, current) =>
          previous.currentPath != current.currentPath,
      listener: (context, state) {
        // Solo actualiza el controlador si el path del bloc cambió y es distinto al texto actual
        if (_controller.text != state.currentPath) {
          _controller.text = state.currentPath;
        }
      },
      child: BlocBuilder<DirectoryBloc, DirectoryState>(
        builder: (context, state) {
          if (state.currentPath.isEmpty) {
            return const SizedBox.shrink();
          }

          final colorScheme = Theme.of(context).colorScheme;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: TextFormField(
              controller: _controller,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Escribe una ruta y presiona Enter',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  final dir = Directory(value);
                  if (dir.existsSync()) {
                    context.read<DirectoryBloc>().add(LoadDirectory(value));
                  }
                }
              },
            ),
          );
        },
      ),
    );
  }
}
