import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'dart:io';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:lanify/widgets/audio_handler.dart';
import 'package:path_provider/path_provider.dart';
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

class AudioFileExplorer extends StatefulWidget {
  const AudioFileExplorer({super.key});

  @override
  State<AudioFileExplorer> createState() => _AudioFileExplorerState();
}

class _AudioFileExplorerState extends State<AudioFileExplorer> {
  List<FileSystemEntity> audioFiles = [];
  String currentPath = '';
  bool isLoading = false;

  // Audio Service Handler
  late AudioHandler _audioHandler;

  // Variables del reproductor
  bool isPlaying = false;
  bool isPaused = false;
  String? currentlyPlaying;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;
  int currentTrackIndex = -1;
  List<File> currentPlaylist = [];
  List<MediaItem> currentMediaItems = [];

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
    debugPrint('initState: Inicializando AudioFileExplorer');
    _initAll();
  }

  Future<void> _initAll() async {
    await _initializeAudioService();
    try {
      if (context.mounted && mounted) {
        await requestPermissions(context);
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

  Future<void> _initializeAudioService() async {
    try {
      // debugPrint('_initializeAudioService: Iniciando');

      // Inicializar audio service
      _audioHandler = await AudioService.init(
        builder: () => MyAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.app.channel.audio',
          androidNotificationChannelName: 'Music Player',
          androidNotificationOngoing: true,
          androidShowNotificationBadge: true,
        ),
      );

      // Escuchar cambios de estado
      _audioHandler.playbackState.listen((state) {
        if (mounted) {
          setState(() {
            isPlaying = state.playing;
            isPaused =
                !state.playing &&
                state.processingState == AudioProcessingState.ready;
            // currentPosition se actualizará por el stream de posición
          });
        }
      });

      // Escuchar cambios de media item
      _audioHandler.mediaItem.listen((mediaItem) {
        if (mounted && mediaItem != null) {
          setState(() {
            currentlyPlaying = mediaItem.title;
            totalDuration = mediaItem.duration ?? Duration.zero;
            debugPrint(
              '[AUDIO_EXPLORER] setState totalDuration: '
              '${mediaItem.title} duration=${mediaItem.duration}',
            );
          });
        }
      });

      // Escuchar cambios de posición en tiempo real
      if (_audioHandler is MyAudioHandler) {
        final player = (_audioHandler as MyAudioHandler).player;
        // Buffer para evitar flicker: solo actualiza el UI cuando duration es válido
        Duration? lastDuration;
        player.durationStream.listen((duration) {
          lastDuration = duration;
        });
        player.positionStream.listen((position) {
          if (mounted) {
            debugPrint('Tracking position: $position');
            // Solo actualiza el UI si la duración es válida o la posición es > 0
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
        });
      }

      // debugPrint('_initializeAudioService: Configuración completada');
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
    try {
      _audioHandler.stop();
    } catch (e) {
      debugPrint('Error al liberar audioHandler: $e');
    }
    super.dispose();
  }

  Future<void> _loadDefaultDirectory() async {
    try {
      // debugPrint('_loadDefaultDirectory: Iniciando');
      Directory directory = await getDefaultMusicDirectory();
      // debugPrint('_loadDefaultDirectory: Directorio seleccionado: \'${directory.path}\'');
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
    // debugPrint('_loadDirectoryContents: Cargando $path');
    setState(() {
      isLoading = true;
    });
    try {
      final filteredFiles = await loadDirectoryContents(path, audioExtensions);
      currentPlaylist = filteredFiles.whereType<File>().toList();

      List<MediaItem> mediaItems = [];
      for (final file in currentPlaylist) {
        String title = getFileName(file.path);
        String artist = 'Unknown Artist';
        String album = 'Unknown Album';
        Uri? artUri;

        try {
          final metadata = await MetadataRetriever.fromFile(file);
          if (metadata.trackName != null && metadata.trackName!.isNotEmpty) {
            title = metadata.trackName!;
          }
          if (metadata.trackArtistNames != null &&
              metadata.trackArtistNames!.isNotEmpty) {
            artist = metadata.trackArtistNames!.join(', ');
          }
          if (metadata.albumName != null && metadata.albumName!.isNotEmpty) {
            album = metadata.albumName!;
          }
          if (metadata.albumArt != null && metadata.albumArt!.isNotEmpty) {
            // Guardar la carátula como archivo temporal
            final tempDir = await getTemporaryDirectory();
            final coverFile = File(
              '${tempDir.path}/${file.uri.pathSegments.last}_cover.jpg',
            );
            await coverFile.writeAsBytes(metadata.albumArt!);
            artUri = Uri.file(coverFile.path);
          }
        } catch (e) {
          debugPrint('Error extrayendo metadatos de ${file.path}: $e');
        }

        mediaItems.add(
          MediaItem(
            id: file.path,
            title: title,
            artist: artist,
            album: album,
            artUri: artUri,
            extras: {'path': file.path},
          ),
        );
      }

      currentMediaItems = mediaItems;
      await _audioHandler.updateQueue(currentMediaItems);

      setState(() {
        audioFiles = filteredFiles;
        currentPath = path;
        isLoading = false;
      });
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

  // --- Player controls ---
  Future<void> _playAudio(File audioFile) async {
    try {
      debugPrint('_playAudio: Reproduciendo ${audioFile.path}');

      // Encontrar el índice del archivo en la playlist
      currentTrackIndex = currentPlaylist.indexWhere(
        (file) => file.path == audioFile.path,
      );

      if (currentTrackIndex == -1) {
        debugPrint('Archivo no encontrado en playlist, agregándolo');
        currentPlaylist.add(audioFile);
        currentTrackIndex = currentPlaylist.length - 1;

        // Agregar MediaItem
        final mediaItem = MediaItem(
          id: audioFile.path,
          title: getFileName(audioFile.path),
          artist: 'Unknown Artist',
          album: 'Unknown Album',
          extras: {'path': audioFile.path},
        );
        currentMediaItems.add(mediaItem);
        await _audioHandler.addQueueItems([mediaItem]);
      }

      // Actualizar el índice en el handler y reproducir
      (_audioHandler as MyAudioHandler).updateCurrentIndex(currentTrackIndex);
      await _audioHandler.playMediaItem(currentMediaItems[currentTrackIndex]);

      setState(() {
        currentlyPlaying = getFileName(audioFile.path);
      });
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
      setState(() {
        currentlyPlaying = null;
        currentPosition = Duration.zero;
        totalDuration = Duration.zero;
        currentTrackIndex = -1;
      });
    } catch (e) {
      debugPrint('Error en _stop: $e');
    }
  }

  Future<void> _playNext() async {
    debugPrint('_playNext: Siguiente canción');
    try {
      await _audioHandler.skipToNext();
      currentTrackIndex = (_audioHandler as MyAudioHandler).currentIndex;
    } catch (e) {
      debugPrint('Error en _playNext: $e');
    }
  }

  Future<void> _playPrevious() async {
    debugPrint('_playPrevious: Canción anterior');
    try {
      await _audioHandler.skipToPrevious();
      currentTrackIndex = (_audioHandler as MyAudioHandler).currentIndex;
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                  ),
          ),
          // Mostrar PlayerControls solo si ambos valores son válidos para evitar flicker
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
            ),
        ],
      ),
    );
  }
}
