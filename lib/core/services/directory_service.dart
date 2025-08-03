import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';

/// Servicio para manejar operaciones de directorio
class DirectoryService {

  /// Obtiene el directorio de música por defecto
  Future<Directory> getDefaultMusicDirectory() async {
    if (Platform.isAndroid) {
      Directory dir = Directory('/storage/emulated/0/Music');
      if (!await dir.exists()) {
        dir = Directory('/storage/emulated/0/');
      }
      return dir;
    } else if (Platform.isWindows) {
      String userProfile = Platform.environment['USERPROFILE'] ?? '';
      Directory dir = Directory('$userProfile/Music');
      if (!await dir.exists()) dir = Directory('C:/');
      return dir;
    } else if (Platform.isLinux) {
      String home = Platform.environment['HOME'] ?? '';
      Directory dir = Directory('$home/Music');
      if (!await dir.exists()) {
        dir = Directory(home.isEmpty ? '/' : home);
      }
      return dir;
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  /// Carga el contenido de un directorio
  Future<DirectoryContents> loadDirectoryContents(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      throw Exception('El directorio no existe: $path');
    }

    try {
      final contents = await directory.list().toList();
      final List<Directory> directories = [];
      final List<File> audioFiles = [];

      for (var entity in contents) {
        try {
          if (entity is File) {
            if (_isAudioFile(entity)) {
              audioFiles.add(entity);
            }
          } else if (entity is Directory) {
            directories.add(entity);
          }
        } catch (e) {
          debugPrint('Error procesando entidad ${entity.path}: $e');
        }
      }

      // Ordenar directorios y archivos
      directories.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
      audioFiles.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

      return DirectoryContents(
        directories: directories,
        audioFiles: audioFiles,
      );
    } catch (e) {
      throw Exception('Error cargando directorio $path: $e');
    }
  }

  /// Stream que monitorea cambios en un directorio
  Stream<FileSystemEvent> watchDirectory(String path) {
    final directory = Directory(path);
    if (!directory.existsSync()) {
      return const Stream.empty();
    }
    return directory.watch(recursive: false);
  }

  /// Verifica si un archivo es de audio
  bool _isAudioFile(File file) {
    return AppConstants.isAudioFile(file.path);
  }
}

/// Clase que contiene el contenido de un directorio
class DirectoryContents {
  final List<Directory> directories;
  final List<File> audioFiles;

  const DirectoryContents({
    required this.directories,
    required this.audioFiles,
  });
}
