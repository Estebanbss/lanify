import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'dart:io';
import 'dart:async';
import 'audio_metadata_loader.dart';
import 'audio_playback_controller.dart';
import 'package:lanify/widgets/audio_handler.dart';
import 'directory_picker.dart';
import 'package:flutter/services.dart';

import 'audio_utils.dart';
import 'directory_utils.dart';
import 'permission_utils.dart';

import 'player_controls.dart';
import 'audio_file_list.dart';
import 'error_snackbar.dart';
import 'path_navigator.dart';
import 'file_directory_counter.dart';
import 'loading_indicator.dart';
import 'reactive_file_manager.dart';
import 'audio_playlist_manager.dart';

class AudioFileExplorer extends StatefulWidget {
  const AudioFileExplorer({super.key});

  @override
  State<AudioFileExplorer> createState() => _AudioFileExplorerState();
}

class _AudioFileExplorerState extends State<AudioFileExplorer> {
  Color? _dominantColor;

  // Manager reactivo centralizado
  final ReactiveFileManager _fileManager = ReactiveFileManager();
  final AudioPlaylistManager _playlistManager = AudioPlaylistManager();

  // Subscripciones a streams
  StreamSubscription<List<FileSystemEntity>>? _filesSubscription;
  StreamSubscription<Map<String, MediaItem>>? _metadataSubscription;

  // Set para evitar procesamiento múltiple de renombrados
  final Set<String> _processingRenames = {};

  void _onDominantColorChanged(Color? color) {
    setState(() {
      _dominantColor = color;
    });
  }

  void _onMetadataUpdated(String filePath, MediaItem updatedMediaItem) async {
    final oldPath = updatedMediaItem.extras?['originalPath'] ?? filePath;
    final newPath = updatedMediaItem.extras?['newPath'] ?? filePath;

    // Crear clave única para este renombrado
    final renameKey = '$oldPath->$newPath';

    // Si ya se está procesando este renombrado, salir
    if (_processingRenames.contains(renameKey)) {
      debugPrint('_onMetadataUpdated: Ya procesando $renameKey, omitiendo...');
      return;
    }

    debugPrint('_onMetadataUpdated: oldPath=$oldPath, newPath=$newPath');

    // Si no hay cambio de ruta, solo actualizar metadatos
    if (oldPath == newPath) {
      _fileManager.updateFileMetadata(newPath, updatedMediaItem);
      return;
    }

    // Marcar como en procesamiento
    _processingRenames.add(renameKey);

    try {
      // Verificar si el archivo renombrado es el que está reproduciéndose actualmente
      bool isCurrentlyPlayingFile = false;
      Duration? currentPosition;

      if (_playlistManager.currentlyPlaying != null) {
        final currentPlayingPath =
            _playlistManager.currentTrackIndex >= 0 &&
                _playlistManager.currentTrackIndex <
                    _playlistManager.currentPlaylist.length
            ? _playlistManager
                  .currentPlaylist[_playlistManager.currentTrackIndex]
                  .path
            : null;

        if (currentPlayingPath == oldPath) {
          isCurrentlyPlayingFile = true;
          debugPrint(
            'El archivo que se está reproduciendo fue renombrado: $oldPath -> $newPath',
          );

          // Guardar la posición actual antes de detener
          try {
            currentPosition = await _audioHandler.playbackState.first.then(
              (state) => state.position,
            );
          } catch (e) {
            debugPrint('Error obteniendo posición: $e');
            currentPosition = Duration.zero;
          }

          // Detener completamente ANTES de hacer cualquier cambio
          debugPrint('Deteniendo reproducción para renombrado...');
          await _audioHandler.stop();

          // Esperar para asegurar que el reproductor se ha detenido completamente
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      // Actualizar sistemas con archivo renombrado
      debugPrint('Actualizando sistemas con archivo renombrado...');
      _fileManager.handleFileRenamed(oldPath, newPath, updatedMediaItem);
      _playlistManager.handleFileRename(oldPath, newPath, updatedMediaItem);

      // Si era el archivo actual, esperar a que el file system se sincronice y reiniciar
      if (isCurrentlyPlayingFile) {
        debugPrint('Esperando sincronización del file system...');

        // Esperar hasta que el archivo aparezca en el sistema de archivos
        bool fileExists = false;
        int attempts = 0;
        const maxAttempts = 20; // 2 segundos máximo

        while (!fileExists && attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 100));
          fileExists = File(newPath).existsSync();
          attempts++;

          if (fileExists) {
            // Verificar que también esté en la playlist actualizada
            final newIndex = _playlistManager.currentPlaylist.indexWhere(
              (file) => file.path == newPath,
            );

            if (newIndex >= 0) {
              debugPrint(
                'Archivo encontrado y sincronizado. Reiniciando reproducción en índice: $newIndex desde posición: $currentPosition',
              );

              // Reproducir el archivo con la nueva ruta
              await _playAudio(File(newPath));

              // Intentar restaurar la posición si es posible
              if (currentPosition != null && currentPosition > Duration.zero) {
                try {
                  await Future.delayed(const Duration(milliseconds: 200));
                  await _audioHandler.seek(currentPosition);
                  debugPrint(
                    'Posición restaurada exitosamente: $currentPosition',
                  );
                } catch (e) {
                  debugPrint('Error restaurando posición: $e');
                }
              }
              break;
            } else {
              // El archivo existe pero no está en la playlist, seguir esperando
              fileExists = false;
            }
          }
        }

        if (!fileExists) {
          debugPrint(
            'Timeout: No se pudo sincronizar el archivo renombrado después de ${maxAttempts * 100}ms',
          );
        }
      }
    } catch (e) {
      debugPrint('_onMetadataUpdated: Error durante renombrado: $e');
    } finally {
      // Remover de la lista de procesamiento
      _processingRenames.remove(renameKey);

      // Recargar directorio actual después de completar el renombrado
      if (currentPath.isNotEmpty) {
        debugPrint(
          'Recargando directorio actual después del renombrado: $currentPath',
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          _loadDirectoryContents(currentPath);
        });
      }
    }
  }

  List<FileSystemEntity> audioFiles = [];
  String currentPath = '';
  bool isLoading = false;

  // Audio Service Handler
  late AudioHandler _audioHandler;

  // Variables del reproductor usando el playlist manager
  bool isPlaying = false;
  bool isPaused = false;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;

  // Getters que delegan al playlist manager
  String? get currentlyPlaying => _playlistManager.currentlyPlaying;
  int get currentTrackIndex => _playlistManager.currentTrackIndex;
  List<File> get currentPlaylist => _playlistManager.currentPlaylist;
  List<MediaItem> get currentMediaItems => _playlistManager.currentMediaItems;

  // Para cancelar operaciones de metadatos cuando cambie de directorio
  bool _cancelMetadataLoading = false;

  // Extensiones de audio soportadas
  final Set<String> audioExtensions = {
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

  @override
  void initState() {
    super.initState();
    debugPrint(
      'initState: Inicializando AudioFileExplorer con sistema reactivo',
    );

    // Configurar listeners para el playlist manager
    _playlistManager.addListener(_onPlaylistUpdated);

    // Configurar subscripciones a streams reactivos
    _filesSubscription = _fileManager.filesStream.listen((files) {
      if (mounted) {
        setState(() {
          audioFiles = files;
        });
        debugPrint(
          'ReactiveFileManager: Archivos actualizados (${files.length})',
        );
      }
    });

    _metadataSubscription = _fileManager.metadataStream.listen((metadata) {
      if (mounted) {
        // Actualizar playlist con los nuevos metadatos
        final audioFilesList = audioFiles.whereType<File>().toList();
        final mediaItems = audioFilesList.map((file) {
          return metadata[file.path] ??
              AudioPlaybackController.createBasicMediaItem(file);
        }).toList();

        _playlistManager.updatePlaylist(audioFilesList, mediaItems);

        setState(() {});
        debugPrint(
          'ReactiveFileManager: Metadatos actualizados (${metadata.length})',
        );
      }
    });

    _initAll();
  }

  void _onPlaylistUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initAll() async {
    await _initializeAudioService();
    try {
      if (context.mounted && mounted) {
        // Solicitar permisos específicos para Android moderno
        await _requestStoragePermissions();
        if (context.mounted && mounted) {
          await requestPermissions(context);
        }
      }
    } catch (e) {
      debugPrint('Error en requestPermissions: $e');
    }
    try {
      await _loadDefaultDirectory();
    } catch (e) {
      debugPrint('Error en _loadDefaultDirectory: $e');
    }
  }

  Future<void> _requestStoragePermissions() async {
    try {
      // Para Android 13+ (API 33+) usar permisos específicos de media
      if (await Permission.audio.request().isGranted) {
        debugPrint('Permiso de audio concedido');
      } else {
        debugPrint('Permiso de audio denegado');
      }

      // Para escritura en almacenamiento externo
      if (await Permission.manageExternalStorage.request().isGranted) {
        debugPrint('Permiso de gestión de almacenamiento externo concedido');
      } else {
        debugPrint('Permiso de gestión de almacenamiento externo denegado');

        // Fallback a permiso de almacenamiento tradicional
        final storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) {
          debugPrint('Permiso de almacenamiento tradicional concedido');
        } else {
          debugPrint('Permiso de almacenamiento tradicional denegado');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Permisos de almacenamiento necesarios para renombrar archivos. '
                  'Algunos archivos en almacenamiento externo no se podrán renombrar.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 6),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error solicitando permisos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error solicitando permisos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _initializeAudioService() async {
    try {
      _audioHandler = await AudioService.init(
        builder: () => MyAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.app.channel.audio',
          androidNotificationChannelName: 'Music Player',
          androidNotificationOngoing: true,
          androidShowNotificationBadge: true,
        ),
      );

      // Inicializar el playlist manager con el audio handler
      if (_audioHandler is MyAudioHandler) {
        _playlistManager.initialize(_audioHandler as MyAudioHandler);
      }

      // Escuchar cambios de estado
      _audioHandler.playbackState.listen((state) {
        if (mounted) {
          setState(() {
            isPlaying = state.playing;
            isPaused =
                !state.playing &&
                state.processingState == AudioProcessingState.ready;
          });
        }
      });

      // Escuchar cambios de media item
      _audioHandler.mediaItem.listen((mediaItem) {
        if (mounted && mediaItem != null) {
          // Evitar actualizaciones innecesarias para prevenir bucles infinitos
          final fileName = getFileName(mediaItem.id);
          final index = _playlistManager.findTrackIndex(mediaItem.id);
          final newDuration = mediaItem.duration ?? Duration.zero;

          // Solo actualizar si hay cambios significativos
          bool shouldUpdate = false;

          if (_playlistManager.currentlyPlaying != fileName ||
              _playlistManager.currentTrackIndex != index) {
            shouldUpdate = true;
          }

          if (totalDuration != newDuration && newDuration > Duration.zero) {
            shouldUpdate = true;
          }

          if (shouldUpdate) {
            setState(() {
              _playlistManager.setCurrentTrack(mediaItem.id, index);
              if (newDuration > Duration.zero) {
                totalDuration = newDuration;
                debugPrint(
                  '[AUDIO_EXPLORER] setState totalDuration: '
                  '${mediaItem.title} duration=${mediaItem.duration}',
                );
              }
            });
          }
        }
      });

      // Escuchar cambios de posición en tiempo real
      if (_audioHandler is MyAudioHandler) {
        final player = (_audioHandler as MyAudioHandler).player;
        Duration? lastDuration;
        Duration lastPosition = Duration.zero;

        player.durationStream.listen((duration) {
          lastDuration = duration;
          if (mounted &&
              duration != null &&
              duration > Duration.zero &&
              totalDuration != duration) {
            setState(() {
              totalDuration = duration;
            });
          }
        });

        player.positionStream.listen((position) {
          if (mounted) {
            // Solo actualizar posición si ha cambiado significativamente (más de 1 segundo)
            if ((position - lastPosition).abs() >= const Duration(seconds: 1) ||
                position == Duration.zero) {
              lastPosition = position;
              debugPrint('Tracking position: $position');

              if ((lastDuration != null && lastDuration! > Duration.zero) ||
                  position > Duration.zero) {
                setState(() {
                  currentPosition = position;
                  debugPrint(
                    '[AUDIO_EXPLORER] setState currentPosition: $position, totalDuration: $totalDuration',
                  );
                });
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error en _initializeAudioService: $e');
      if (context.mounted && mounted) {
        ErrorSnackbar.show(context, 'Error inicializando audio service: $e');
      }
    }
  }

  @override
  void dispose() {
    debugPrint('dispose: Liberando recursos');
    _cancelMetadataLoading = true;

    // Cancelar subscripciones a streams reactivos
    _filesSubscription?.cancel();
    _metadataSubscription?.cancel();

    // Remover listeners
    _playlistManager.removeListener(_onPlaylistUpdated);

    try {
      _audioHandler.stop();
    } catch (e) {
      debugPrint('Error al liberar audioHandler: $e');
    }
    super.dispose();
  }

  Future<void> _loadDefaultDirectory() async {
    try {
      Directory directory = await getDefaultMusicDirectory();
      await _loadDirectoryContents(directory.path);
    } catch (e) {
      debugPrint('Error en _loadDefaultDirectory: $e');
      if (context.mounted && mounted) {
        ErrorSnackbar.show(
          context,
          'Error al cargar el directorio por defecto: $e',
        );
      }
    }
  }

  Future<void> _loadDirectoryContents(String path) async {
    setState(() {
      isLoading = true;
      _cancelMetadataLoading = true; // Cancelar operaciones previas
    });

    // Pequeño delay para permitir cancelación
    await Future.delayed(const Duration(milliseconds: 10));
    _cancelMetadataLoading = false;

    try {
      final filteredFiles = await loadDirectoryContents(path, audioExtensions);
      final audioFilesList = filteredFiles.whereType<File>().toList();

      List<MediaItem> basicMediaItems = [];
      for (final file in audioFilesList) {
        final cachedMetadata = _fileManager.getMetadata(file.path);
        if (cachedMetadata != null) {
          basicMediaItems.add(cachedMetadata);
        } else {
          final basicItem = AudioPlaybackController.createBasicMediaItem(file)
              .copyWith(
                artist: 'Loading...',
                album: 'Loading...',
                extras: {'path': file.path, 'hasMetadata': false},
              );
          basicMediaItems.add(basicItem);
        }
      }

      // Actualizar usando el playlist manager
      _playlistManager.updatePlaylist(audioFilesList, basicMediaItems);

      setState(() {
        audioFiles = filteredFiles;
        currentPath = path;
        isLoading = false;
      });

      _loadMetadataInBackground();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint('Error en _loadDirectoryContents: $e');
      if (context.mounted && mounted) {
        ErrorSnackbar.show(context, 'Error al leer el directorio: $e');
      }
    }
  }

  Future<void> _loadMetadataInBackground() async {
    debugPrint(
      'Iniciando carga de metadatos en background para \\${currentPlaylist.length} archivos',
    );
    const batchSize = 5;
    for (int i = 0; i < currentPlaylist.length; i += batchSize) {
      if (_cancelMetadataLoading) {
        debugPrint('Carga de metadatos cancelada');
        return;
      }
      final batch = currentPlaylist.skip(i).take(batchSize).toList();
      await _processBatch(batch, i);
      await Future.delayed(const Duration(milliseconds: 50));
    }
    debugPrint('Carga de metadatos completada');
  }

  Future<void> _processBatch(List<File> batch, int startIndex) async {
    bool hasUpdates = false;
    final currentMediaItemsCopy = List<MediaItem>.from(currentMediaItems);

    for (int i = 0; i < batch.length; i++) {
      if (_cancelMetadataLoading) return;
      final file = batch[i];
      final globalIndex = startIndex + i;

      // Verificar si ya tenemos los metadatos
      if (_fileManager.getMetadata(file.path) != null) {
        continue;
      }

      try {
        final mediaItem = await AudioMetadataLoader.extractMetadataForFile(
          file,
        );

        // Actualizar metadatos con el sistema reactivo
        _fileManager.updateMetadata(file.path, mediaItem);

        // Actualizar la copia local de la lista
        if (globalIndex < currentMediaItemsCopy.length) {
          currentMediaItemsCopy[globalIndex] = mediaItem;
          hasUpdates = true;
        }
      } catch (e) {
        debugPrint('Error extrayendo metadatos de \\${file.path}: $e');
        final basicItem = AudioPlaybackController.createBasicMediaItem(
          file,
        ).copyWith(extras: {'path': file.path, 'hasMetadata': true});

        // Actualizar metadatos con el sistema reactivo
        _fileManager.updateMetadata(file.path, basicItem);

        // Actualizar la copia local de la lista
        if (globalIndex < currentMediaItemsCopy.length) {
          currentMediaItemsCopy[globalIndex] = basicItem;
          hasUpdates = true;
        }
      }
    }

    if (hasUpdates && mounted && !_cancelMetadataLoading) {
      // Actualizar el playlist manager con los nuevos metadatos
      _playlistManager.updatePlaylist(currentPlaylist, currentMediaItemsCopy);
      setState(() {});
    }
  }

  // _extractMetadataForFile ahora está en audio_metadata_loader.dart

  // --- Player controls ---
  Future<void> _playAudio(File audioFile) async {
    try {
      debugPrint('_playAudio: Reproduciendo \\${audioFile.path}');

      int trackIndex = _playlistManager.findTrackIndex(audioFile.path);
      if (trackIndex == -1) {
        debugPrint('Archivo no encontrado en playlist, agregándolo');
        final currentPlaylistCopy = List<File>.from(currentPlaylist);
        final currentMediaItemsCopy = List<MediaItem>.from(currentMediaItems);

        currentPlaylistCopy.add(audioFile);
        trackIndex = currentPlaylistCopy.length - 1;

        MediaItem mediaItem;
        final cachedMetadata = _fileManager.getMetadata(audioFile.path);
        if (cachedMetadata != null) {
          mediaItem = cachedMetadata;
        } else {
          mediaItem = AudioPlaybackController.createBasicMediaItem(audioFile);
        }
        currentMediaItemsCopy.add(mediaItem);

        // Actualizar el playlist manager
        _playlistManager.updatePlaylist(
          currentPlaylistCopy,
          currentMediaItemsCopy,
        );
      }

      // Actualizar la canción actual en el playlist manager
      _playlistManager.setCurrentTrack(audioFile.path, trackIndex);

      // Actualizar el audio handler
      if (_audioHandler is MyAudioHandler) {
        (_audioHandler as MyAudioHandler).updateCurrentIndex(trackIndex);
        await _audioHandler.playMediaItem(currentMediaItems[trackIndex]);
      }

      setState(() {});
    } catch (e) {
      debugPrint('Error reproduciendo audio: $e');
      if (context.mounted && mounted) {
        ErrorSnackbar.show(context, 'Error al reproducir: $e');
      }
    }
  }

  Future<void> _pauseResume() async {
    debugPrint('_pauseResume: isPlaying=$isPlaying, isPaused=$isPaused');
    try {
      if (isPlaying) {
        await _audioHandler.pause();
      } else {
        await _audioHandler.play();
      }
    } catch (e) {
      debugPrint('Error en _pauseResume: $e');
    }
  }

  Future<void> _stop() async {
    debugPrint('_stop: Deteniendo reproducción');
    try {
      await _audioHandler.stop();
      // Limpiar el estado usando el playlist manager
      _playlistManager.setCurrentTrack(null, -1);
      setState(() {
        currentPosition = Duration.zero;
        totalDuration = Duration.zero;
      });
    } catch (e) {
      debugPrint('Error en _stop: $e');
    }
  }

  Future<void> _playNext() async {
    debugPrint('_playNext: Siguiente canción');
    try {
      await _audioHandler.skipToNext();
      // El índice se actualizará automáticamente a través del mediaItem listener
    } catch (e) {
      debugPrint('Error en _playNext: $e');
    }
  }

  Future<void> _playPrevious() async {
    debugPrint('_playPrevious: Canción anterior');
    try {
      await _audioHandler.skipToPrevious();
      // El índice se actualizará automáticamente a través del mediaItem listener
    } catch (e) {
      debugPrint('Error en _playPrevious: $e');
    }
  }

  Future<void> _seekTo(Duration position) async {
    debugPrint('_seekTo: $position');
    try {
      await _audioHandler.seek(position);
    } catch (e) {
      debugPrint('Error en _seekTo: $e');
    }
  }

  // --- Directory selection ---
  Future<void> _selectDirectoryNative() async {
    debugPrint('_selectDirectoryNative: Seleccionando directorio');
    try {
      String? selectedDirectory = await DirectoryPicker.selectDirectoryNative(
        context,
      );
      debugPrint(
        '_selectDirectoryNative: Directorio seleccionado: $selectedDirectory',
      );
      if (selectedDirectory != null) {
        await _loadDirectoryContents(selectedDirectory);
      }
    } catch (e) {
      debugPrint('Error en _selectDirectoryNative: $e');
      if (context.mounted && mounted) {
        ErrorSnackbar.show(context, 'Error al seleccionar directorio: $e');
      }
    }
  }

  void _navigateToPath(String path) {
    if (path.isNotEmpty) _loadDirectoryContents(path);
  }

  void _navigateToParentDirectory() {
    if (currentPath.isNotEmpty) {
      Directory parent = Directory(currentPath).parent;
      _loadDirectoryContents(parent.path);
    }
  }

  void _copyCurrentPath() {
    Clipboard.setData(ClipboardData(text: currentPath));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ruta copiada al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: PathNavigator(
          currentPath: currentPath,
          onNavigate: _navigateToPath,
          onNavigateParent: _navigateToParentDirectory,
          onCopy: _copyCurrentPath,
        ),
        backgroundColor:
            _dominantColor ?? Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _selectDirectoryNative,
            tooltip: 'Seleccionar directorio',
          ),
          if (currentPath.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              onPressed: _navigateToParentDirectory,
              tooltip: 'Directorio padre',
            ),
        ],
      ),
      body: Column(
        children: [
          FileDirectoryCounter(
            audioFileCount: audioFiles.whereType<File>().length,
            directoryCount: audioFiles.whereType<Directory>().length,
          ),
          Expanded(
            child: isLoading
                ? const LoadingIndicator()
                : AudioFileList(
                    audioFiles: audioFiles,
                    currentlyPlaying: currentlyPlaying,
                    isPlaying: isPlaying,
                    onDirectoryTap: (path) => _loadDirectoryContents(path),
                    onFileTap: (file, isCurrentTrack) {
                      if (isCurrentTrack && isPlaying) {
                        _pauseResume();
                      } else {
                        _playAudio(file);
                      }
                    },
                    getFileName: getFileName,
                    getFileExtension: getFileExtension,
                    formatFileSize: formatFileSize,
                    onDominantColorChanged: _onDominantColorChanged,
                    onMetadataUpdated: _onMetadataUpdated,
                  ),
          ),
          if (totalDuration > Duration.zero && currentPosition >= Duration.zero)
            PlayerControls(
              currentlyPlaying: currentlyPlaying,
              currentTrackIndex: currentTrackIndex,
              playlistLength: currentPlaylist.length,
              currentPosition: currentPosition,
              totalDuration: totalDuration,
              isPlaying: isPlaying,
              onPlayPause: _pauseResume,
              onStop: _stop,
              onNext: _playNext,
              onPrevious: _playPrevious,
              onSeek: _seekTo,
              formatDuration: formatDuration,
              backgroundColor: _dominantColor,
            ),
        ],
      ),
    );
  }

  void invalidateCache() {
    // En el sistema reactivo no necesitamos limpiar cache
    // El sistema se actualiza automáticamente
    _loadDirectoryContents(currentPath);
  }
}
