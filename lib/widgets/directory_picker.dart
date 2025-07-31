import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'path_input_dialog.dart';

class DirectoryPicker {
  static Future<String?> selectDirectoryNative(BuildContext context) async {
    String? selectedDirectory;
    if (Platform.isLinux) {
      selectedDirectory = await _pickDirectoryWithFallback(context);
    } else {
      selectedDirectory = await FilePicker.platform.getDirectoryPath();
    }
    return selectedDirectory;
  }

  static Future<String?> _pickDirectoryWithFallback(
    BuildContext context,
  ) async {
    final tools = ['zenity', 'kdialog', 'dialog', 'whiptail'];
    for (final tool in tools) {
      try {
        final result = await Process.run('which', [tool]);
        if ((result.stdout as String).trim().isNotEmpty) {
          final selectedPath = await _pickWithTool(tool);
          if (selectedPath != null) return selectedPath;
        }
      } catch (_) {
        continue;
      }
    }
    if (context.mounted) {
      return await _showManualPathDialog(context);
    }
    return null;
  }

  static Future<String?> _pickWithTool(String tool) async {
    try {
      ProcessResult result;
      switch (tool) {
        case 'zenity':
          result = await Process.run('zenity', [
            '--file-selection',
            '--directory',
            '--title=Selecciona una carpeta de música',
          ]);
          if (result.exitCode == 0) return (result.stdout as String).trim();
          break;
        case 'kdialog':
          result = await Process.run('kdialog', [
            '--getexistingdirectory',
            Platform.environment['HOME'] ?? '.',
            '--title',
            'Selecciona una carpeta de música',
          ]);
          if (result.exitCode == 0) return (result.stdout as String).trim();
          break;
        case 'dialog':
        case 'whiptail':
          result = await Process.run(tool, [
            '--inputbox',
            'Escribe el path del directorio:',
            '10',
            '50',
            Platform.environment['HOME'] ?? '.',
          ], stdoutEncoding: utf8);
          if (result.exitCode == 0) {
            final path = (result.stdout as String).trim();
            if (path.isNotEmpty && await Directory(path).exists()) return path;
          }
          break;
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _showManualPathDialog(BuildContext context) async {
    TextEditingController pathController = TextEditingController(
      text: Platform.environment['HOME'] ?? '',
    );
    String? result;
    try {
      result = await showDialog<String>(
        context: context,
        builder: (context) => PathInputDialog(
          controller: pathController,
          title: 'Seleccionar directorio',
          label: 'Ruta del directorio',
          hint: '/home/usuario/Music',
          onSelect: () {
            String path = pathController.text.trim();
            Navigator.of(context).pop(path.isNotEmpty ? path : null);
          },
        ),
      );
    } catch (_) {}
    return result;
  }
}
