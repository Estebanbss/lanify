import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'audio_metadata_loader.dart';
import 'audio_playback_controller.dart';

/// Sistema reactivo para monitorear cambios en el sistema de archivos
class ReactiveFileManager extends ChangeNotifier {
  static final ReactiveFileManager _instance = ReactiveFileManager._internal();
  factory ReactiveFileManager() => _instance;
  ReactiveFileManager._internal();

  // Streams para cambios en tiempo real
  final _filesController = StreamController<List<FileSystemEntity>>.broadcast();
  final _metadataController =
      StreamController<Map<String, MediaItem>>.broadcast();

  // Estado actual
  List<FileSystemEntity> _currentFiles = [];
  Map<String, MediaItem> _currentMetadata = {};
  String _currentPath = '';

  // Cache para colores dominantes y futures de metadatos
  final Map<String, Color> _dominantColors = {};
  final Map<String, Future<MediaItem>> _metadataFutures = {};

  // Watcher para monitorear cambios en el directorio
  StreamSubscription<FileSystemEvent>? _directoryWatcher;

  // Timer para debounce de cambios
  Timer? _debounceTimer;

  // Flag para ignorar eventos del watcher durante operaciones manuales
  bool _ignoreWatcherEvents = false;
  Timer? _ignoreTimer;

  // Extensiones de audio soportadas
  final Set<String> _audioExtensions = {
    '.mp3',
    '.flac',
    '.wav',
    '.aac',
    '.ogg',
    '.m4a',
    '.wma',
    '.opus',
    '.mp4',
    '.3gp',
  };

  // Getters para streams
  Stream<List<FileSystemEntity>> get filesStream => _filesController.stream;
  Stream<Map<String, MediaItem>> get metadataStream =>
      _metadataController.stream;

  // Getters para estado actual
  List<FileSystemEntity> get currentFiles => List.unmodifiable(_currentFiles);
  Map<String, MediaItem> get currentMetadata =>
      Map.unmodifiable(_currentMetadata);
  String get currentPath => _currentPath;

  /// Inicia el monitoreo de un directorio
  Future<void> watchDirectory(String path) async {
    debugPrint('ReactiveFileManager: Iniciando monitoreo de $path');

    // Cancelar watcher anterior
    await _stopWatching();

    _currentPath = path;

    // Cargar archivos iniciales
    await _loadDirectoryContents(path);

    // Iniciar watcher del directorio
    _startWatching(path);
  }

  /// Detiene el monitoreo actual
  Future<void> _stopWatching() async {
    await _directoryWatcher?.cancel();
    _directoryWatcher = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _ignoreTimer?.cancel();
    _ignoreTimer = null;
    _ignoreWatcherEvents = false;
  }

  /// Inicia el watcher del directorio
  void _startWatching(String path) {
    try {
      final directory = Directory(path);
      if (!directory.existsSync()) return;

      _directoryWatcher = directory
          .watch(recursive: false)
          .listen(
            (event) {
              debugPrint(
                'ReactiveFileManager: Evento del sistema de archivos: ${event.type} - ${event.path}',
              );
              _handleFileSystemEvent(event);
            },
            onError: (error) {
              debugPrint('ReactiveFileManager: Error en watcher: $error');
            },
          );
    } catch (e) {
      debugPrint('ReactiveFileManager: Error iniciando watcher: $e');
    }
  }

  /// Maneja eventos del sistema de archivos
  void _handleFileSystemEvent(FileSystemEvent event) {
    // Ignorar eventos si estamos en una operación manual
    if (_ignoreWatcherEvents) {
      debugPrint(
        'ReactiveFileManager: Ignorando evento del watcher durante operación manual',
      );
      return;
    }

    // Usar debounce para evitar recargas excesivas
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _reloadCurrentDirectory();
    });
  }

  /// Recarga el directorio actual
  Future<void> _reloadCurrentDirectory() async {
    if (_currentPath.isNotEmpty) {
      debugPrint(
        'ReactiveFileManager: Recargando directorio por cambio en el sistema de archivos',
      );
      await _loadDirectoryContents(_currentPath);
    }
  }

  /// Carga el contenido del directorio
  Future<void> _loadDirectoryContents(String path) async {
    try {
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
            if (_audioExtensions.contains('.$extension')) {
              filteredFiles.add(entity);
            }
          } else if (entity is Directory) {
            filteredFiles.add(entity);
          }
        } catch (e) {
          debugPrint('ReactiveFileManager: Error filtrando entidad: $e');
        }
      }

      // Ordenar archivos
      filteredFiles.sort((a, b) {
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      _currentFiles = filteredFiles;
      _filesController.add(_currentFiles);

      // Cargar metadatos de archivos de audio
      await _loadMetadataForAudioFiles();
    } catch (e) {
      debugPrint('ReactiveFileManager: Error cargando directorio: $e');
      _currentFiles = [];
      _filesController.add(_currentFiles);
    }
  }

  /// Carga metadatos para archivos de audio
  Future<void> _loadMetadataForAudioFiles() async {
    final audioFiles = _currentFiles.whereType<File>().toList();
    final newMetadata = <String, MediaItem>{};

    debugPrint(
      'ReactiveFileManager: Cargando metadatos para ${audioFiles.length} archivos',
    );

    // Procesar archivos en lotes pequeños para no bloquear la UI
    const batchSize = 3;
    for (int i = 0; i < audioFiles.length; i += batchSize) {
      final batch = audioFiles.skip(i).take(batchSize).toList();

      final futures = batch.map((file) async {
        try {
          // Verificar si el archivo aún existe (podría haber sido eliminado)
          if (!await file.exists()) {
            return null;
          }

          final mediaItem = await AudioMetadataLoader.extractMetadataForFile(
            file,
          );
          return MapEntry(file.path, mediaItem);
        } catch (e) {
          debugPrint(
            'ReactiveFileManager: Error cargando metadatos para ${file.path}: $e',
          );
          // Crear item básico en caso de error
          final basicItem = AudioPlaybackController.createBasicMediaItem(file);
          return MapEntry(file.path, basicItem);
        }
      });

      final results = await Future.wait(futures);

      for (final result in results) {
        if (result != null) {
          newMetadata[result.key] = result.value;
        }
      }

      // Emitir actualización parcial de metadatos
      _currentMetadata = {..._currentMetadata, ...newMetadata};
      _metadataController.add(_currentMetadata);

      // Pequeña pausa entre lotes
      await Future.delayed(const Duration(milliseconds: 50));
    }

    debugPrint(
      'ReactiveFileManager: Metadatos cargados para ${newMetadata.length} archivos',
    );
  }

  /// Fuerza la recarga del directorio actual
  Future<void> forceReload() async {
    debugPrint('ReactiveFileManager: Forzando recarga del directorio');
    if (_currentPath.isNotEmpty) {
      // Limpiar metadatos actuales
      _currentMetadata.clear();
      _metadataController.add(_currentMetadata);

      // Recargar todo
      await _loadDirectoryContents(_currentPath);
    }
  }

  /// Actualiza los metadatos de un archivo específico
  Future<void> updateFileMetadata(
    String filePath,
    MediaItem updatedItem,
  ) async {
    debugPrint('ReactiveFileManager: Actualizando metadatos para $filePath');

    _currentMetadata[filePath] = updatedItem;
    _metadataController.add(_currentMetadata);
    notifyListeners();
  }

  /// Maneja el renombrado de un archivo
  Future<void> handleFileRenamed(
    String oldPath,
    String newPath,
    MediaItem updatedItem,
  ) async {
    debugPrint(
      'ReactiveFileManager: Manejando renombrado $oldPath -> $newPath',
    );

    // Ignorar eventos del watcher durante esta operación
    _ignoreWatcherEvents = true;
    _ignoreTimer?.cancel();
    _ignoreTimer = Timer(const Duration(milliseconds: 500), () {
      _ignoreWatcherEvents = false;
      debugPrint('ReactiveFileManager: Reactivando eventos del watcher');
    });

    // 1. Actualizar metadatos inmediatamente
    _currentMetadata.remove(oldPath);
    _currentMetadata[newPath] = updatedItem;

    // 2. Actualizar futures de metadatos si existen
    if (_metadataFutures.containsKey(oldPath)) {
      _metadataFutures[newPath] = _metadataFutures[oldPath]!;
      _metadataFutures.remove(oldPath);
    }

    // 3. Remover colores dominantes del archivo viejo
    _dominantColors.removeWhere((key, value) => key.contains(oldPath));

    // 4. Actualizar la lista de archivos manualmente
    for (int i = 0; i < _currentFiles.length; i++) {
      if (_currentFiles[i].path == oldPath) {
        // Crear una nueva entidad File con la nueva ruta
        _currentFiles[i] = File(newPath);
        break;
      }
    }

    // 5. Emitir actualizaciones
    _filesController.add(List.from(_currentFiles));
    _metadataController.add(Map.from(_currentMetadata));

    debugPrint(
      'ReactiveFileManager: Renombrado completado. Total archivos: ${_currentFiles.length}, Total metadatos: ${_currentMetadata.length}',
    );

    notifyListeners();
  }

  /// Elimina un archivo de los metadatos
  void removeFile(String filePath) {
    debugPrint('ReactiveFileManager: Removiendo archivo $filePath');

    _currentMetadata.remove(filePath);
    _metadataController.add(_currentMetadata);
    notifyListeners();
  }

  /// Obtiene los metadatos para un archivo específico
  MediaItem? getMetadata(String filePath) {
    return _currentMetadata[filePath];
  }

  /// Actualiza los metadatos para un archivo específico
  void updateMetadata(String filePath, MediaItem metadata) {
    _currentMetadata[filePath] = metadata;
    _metadataController.add(Map.from(_currentMetadata));
    debugPrint('ReactiveFileManager: Metadatos actualizados para $filePath');
  }

  /// Obtiene el color dominante para una imagen de arte
  Color? getDominantColor(String artUri) {
    return _dominantColors[artUri];
  }

  /// Actualiza el color dominante para una imagen de arte
  void updateDominantColor(String artUri, Color? color) {
    if (color != null) {
      _dominantColors[artUri] = color;
    } else {
      _dominantColors.remove(artUri);
    }
    debugPrint('ReactiveFileManager: Color dominante actualizado para $artUri');
  }

  /// Obtiene el Future de metadatos para un archivo
  Future<MediaItem>? getMetadataFuture(String filePath) {
    return _metadataFutures[filePath];
  }

  /// Actualiza el Future de metadatos para un archivo
  void updateMetadataFuture(String filePath, Future<MediaItem> future) {
    _metadataFutures[filePath] = future;
  }

  /// Limpia todos los datos
  void clear() {
    debugPrint('ReactiveFileManager: Limpiando todos los datos');

    _currentFiles.clear();
    _currentMetadata.clear();
    _currentPath = '';

    _filesController.add(_currentFiles);
    _metadataController.add(_currentMetadata);

    notifyListeners();
  }

  /// Obtiene estadísticas
  Map<String, dynamic> getStats() {
    return {
      'totalFiles': _currentFiles.length,
      'audioFiles': _currentFiles.whereType<File>().length,
      'directories': _currentFiles.whereType<Directory>().length,
      'metadataLoaded': _currentMetadata.length,
      'currentPath': _currentPath,
      'isWatching': _directoryWatcher != null,
    };
  }

  @override
  void dispose() {
    debugPrint('ReactiveFileManager: Disposing');
    _stopWatching();
    _filesController.close();
    _metadataController.close();
    super.dispose();
  }
}
