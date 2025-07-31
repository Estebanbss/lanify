import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

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

Future<List<FileSystemEntity>> loadDirectoryContents(
  String path,
  Set<String> audioExtensions,
) async {
  final directory = Directory(path);
  if (!await directory.exists()) {
    throw Exception('El directorio no existe');
  }
  final contents = await directory.list().toList();
  final List<FileSystemEntity> filteredFiles = [];
  for (var entity in contents) {
    try {
      if (entity is File) {
        String extension = entity.path.split('.').last.toLowerCase();
        if (audioExtensions.contains('.$extension')) {
          filteredFiles.add(entity);
        }
      } else if (entity is Directory) {
        filteredFiles.add(entity);
      }
    } catch (e) {
      debugPrint('Error filtrando entidad: $e');
    }
  }
  filteredFiles.sort((a, b) {
    if (a is Directory && b is File) return -1;
    if (a is File && b is Directory) return 1;
    return a.path.toLowerCase().compareTo(b.path.toLowerCase());
  });
  return filteredFiles;
}
