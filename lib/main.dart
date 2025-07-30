import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart' hide AVAudioSessionCategory;
import 'package:audio_session/audio_session.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Player Explorer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AudioFileExplorer(),
    );
  }
}

class AudioFileExplorer extends StatefulWidget {
  const AudioFileExplorer({super.key});

  @override
  State<AudioFileExplorer> createState() => _AudioFileExplorerState();
}

class _AudioFileExplorerState extends State<AudioFileExplorer> {
  List<FileSystemEntity> audioFiles = [];
  String currentPath = '';
  bool isLoading = false;

  // Variables del reproductor
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  bool isPaused = false;
  String? currentlyPlaying;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;
  int currentTrackIndex = -1;
  List<File> currentPlaylist = [];

  // Audio Session para controles de medios
  AudioSession? audioSession;

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
    _initializeAudioSession();
    _initializeAudioPlayer();
    _requestPermissions();
  }

  Future<void> _initializeAudioSession() async {
    try {
      audioSession = await AudioSession.instance;

      // Configurar la sesión de audio para música con controles de medios
      await audioSession!.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ),
      );

      // Configurar controles de medios
      await _setupMediaControls();

      // Escuchar eventos de botones de auriculares y controles de medios
      await audioSession!.setActive(true);

      // Manejar interrupciones de audio
      audioSession!.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              // Reducir volumen
              _audioPlayer.setVolume(0.3);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              // Pausar reproducción
              if (isPlaying) {
                _pauseResume();
              }
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              // Restaurar volumen
              _audioPlayer.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
              // Reanudar si estaba pausado por interrupción
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });

      // Manejar eventos de botones de auriculares
      audioSession!.becomingNoisyEventStream.listen((_) {
        // Pausar cuando se desconectan los auriculares
        if (isPlaying) {
          _pauseResume();
        }
      });
    } catch (e) {
      debugPrint('Error inicializando audio session: $e');
    }
  }

  Future<void> _setupMediaControls() async {
    try {
      // Configurar controles de medios para Android/iOS
      if (Platform.isAndroid || Platform.isIOS) {
        // Establecer metadatos de medios
        await audioSession!.setActive(true);

        // Para Android, necesitarías usar un plugin como audio_service
        // Por ahora configuramos lo básico con audio_session

        // Escuchar eventos de controles de medios del sistema
        audioSession!.interruptionEventStream.listen((event) {
          // Manejar controles desde notificaciones y auriculares
          _handleMediaControlEvent(event);
        });
      }
    } catch (e) {
      debugPrint('Error configurando controles de medios: $e');
    }
  }

  void _handleMediaControlEvent(AudioInterruptionEvent event) {
    // Esta función manejaría los eventos de controles de medios
    // Para una implementación completa necesitarías audio_service
    if (event.begin) {
      if (event.type == AudioInterruptionType.pause) {
        _pauseResume();
      }
    }
  }

  void _initializeAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      setState(() {
        isPlaying = state == PlayerState.playing;
        isPaused = state == PlayerState.paused;
      });

      // Actualizar estado en la sesión de audio
      _updateMediaSessionState();
    });

    _audioPlayer.onPositionChanged.listen((Duration position) {
      setState(() {
        currentPosition = position;
      });
    });

    _audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() {
        totalDuration = duration;
      });
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _playNext();
    });
  }

  Future<void> _updateMediaSessionState() async {
    try {
      if (audioSession != null && currentlyPlaying != null) {
        // Actualizar información de la canción actual
        // Para una implementación completa, usarías audio_service aquí
        await audioSession!.setActive(isPlaying);
      }
    } catch (e) {
      debugPrint('Error actualizando estado de medios: $e');
    }
  }

  @override
  void dispose() {
    audioSession?.setActive(false);
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Lista de permisos según la versión de Android
      List<Permission> permissionsToRequest = [];

      // Para Android 13+ (API 33+)
      if (await _isAndroid13OrHigher()) {
        permissionsToRequest.addAll([
          Permission.audio, // Para archivos de audio
          Permission.notification, // Para notificaciones de reproductor
        ]);
      } else {
        // Para versiones anteriores a Android 13
        permissionsToRequest.addAll([
          Permission.storage,
          Permission.manageExternalStorage,
        ]);
      }

      // Solicitar permisos
      Map<Permission, PermissionStatus> permissions = await permissionsToRequest
          .request();

      // Verificar si todos los permisos fueron concedidos
      bool allGranted = permissions.values.every(
        (status) =>
            status == PermissionStatus.granted ||
            status == PermissionStatus.limited,
      );

      if (!allGranted) {
        // Mostrar información específica sobre permisos faltantes
        List<String> deniedPermissions = [];
        permissions.forEach((permission, status) {
          if (status != PermissionStatus.granted &&
              status != PermissionStatus.limited) {
            switch (permission) {
              case Permission.audio:
                deniedPermissions.add('Acceso a archivos de audio');
                break;
              case Permission.storage:
                deniedPermissions.add('Acceso al almacenamiento');
                break;
              case Permission.manageExternalStorage:
                deniedPermissions.add('Administrar almacenamiento externo');
                break;
              case Permission.notification:
                deniedPermissions.add('Mostrar notificaciones');
                break;
              default:
                deniedPermissions.add('Permiso desconocido');
            }
          }
        });

        if (deniedPermissions.isNotEmpty) {
          _showPermissionDialog(deniedPermissions);
        }
      }
    }
    _loadDefaultDirectory();
  }

  // Función auxiliar para verificar si es Android 13+
  Future<bool> _isAndroid13OrHigher() async {
    if (Platform.isAndroid) {
      var androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.version.sdkInt >= 33;
    }
    return false;
  }

  // Mostrar diálogo explicativo sobre permisos
  void _showPermissionDialog(List<String> deniedPermissions) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permisos necesarios'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'La aplicación necesita los siguientes permisos para funcionar correctamente:',
              ),
              const SizedBox(height: 8),
              ...deniedPermissions.map(
                (permission) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6),
                      const SizedBox(width: 8),
                      Expanded(child: Text(permission)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Puedes otorgar estos permisos desde la configuración de la aplicación.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings(); // Abre la configuración de la app
              },
              child: const Text('Ir a configuración'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadDefaultDirectory() async {
    try {
      Directory directory;

      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Music');
        if (!await directory.exists()) {
          directory = Directory('/storage/emulated/0/');
        }
      } else if (Platform.isWindows) {
        String userProfile = Platform.environment['USERPROFILE'] ?? '';
        directory = Directory('$userProfile\\Music');
        if (!await directory.exists()) {
          directory = Directory('C:\\');
        }
      } else if (Platform.isLinux) {
        String home = Platform.environment['HOME'] ?? '';
        directory = Directory('$home/Music');
        if (!await directory.exists()) {
          directory = Directory(home.isEmpty ? '/' : home);
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      await _loadDirectoryContents(directory.path);
    } catch (e) {
      debugPrint('Error al cargar el directorio por defecto: $e');
      _showError('Error al cargar el directorio por defecto: $e');
    }
  }

  Future<void> _loadDirectoryContents(String path) async {
    setState(() {
      isLoading = true;
    });

    try {
      final directory = Directory(path);
      if (!await directory.exists()) {
        _showError('El directorio no existe');
        setState(() {
          isLoading = false;
        });
        return;
      }

      final contents = await directory.list().toList();
      final List<FileSystemEntity> filteredFiles = [];

      for (var entity in contents) {
        if (entity is File) {
          String extension = _getFileExtension(entity.path).toLowerCase();
          if (audioExtensions.contains(extension)) {
            filteredFiles.add(entity);
          }
        } else if (entity is Directory) {
          filteredFiles.add(entity);
        }
      }

      filteredFiles.sort((a, b) {
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      // Actualizar playlist con archivos de audio del directorio actual
      currentPlaylist = filteredFiles.whereType<File>().toList();

      setState(() {
        audioFiles = filteredFiles;
        currentPath = path;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showError('Error al leer el directorio: $e');
    }
  }

  String _getFileExtension(String path) {
    int lastDot = path.lastIndexOf('.');
    if (lastDot == -1) return '';
    return path.substring(lastDot);
  }

  String _getFileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDuration(Duration duration) {
    String minutes = duration.inMinutes.toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // Funciones del reproductor
  Future<void> _playAudio(File audioFile) async {
    try {
      // Activar la sesión de audio
      await audioSession?.setActive(true);

      currentTrackIndex = currentPlaylist.indexOf(audioFile);
      await _audioPlayer.play(DeviceFileSource(audioFile.path));
      setState(() {
        currentlyPlaying = _getFileName(audioFile.path);
      });

      // Actualizar controles de medios
      _updateMediaSessionState();
    } catch (e) {
      _showError('Error al reproducir: $e');
    }
  }

  Future<void> _pauseResume() async {
    if (isPlaying) {
      await _audioPlayer.pause();
    } else if (isPaused) {
      await _audioPlayer.resume();
    }

    // Actualizar controles de medios
    _updateMediaSessionState();
  }

  Future<void> _stop() async {
    await _audioPlayer.stop();
    setState(() {
      currentlyPlaying = null;
      currentPosition = Duration.zero;
      totalDuration = Duration.zero;
      currentTrackIndex = -1;
    });
    // Desactivar la sesión de audio cuando se detiene
    await audioSession?.setActive(false);
  }

  Future<void> _playNext() async {
    if (currentPlaylist.isNotEmpty &&
        currentTrackIndex < currentPlaylist.length - 1) {
      currentTrackIndex++;
      await _playAudio(currentPlaylist[currentTrackIndex]);
    } else if (currentPlaylist.isNotEmpty) {
      // Volver al inicio de la lista
      currentTrackIndex = 0;
      await _playAudio(currentPlaylist[currentTrackIndex]);
    }
  }

  Future<void> _playPrevious() async {
    if (currentPlaylist.isNotEmpty && currentTrackIndex > 0) {
      currentTrackIndex--;
      await _playAudio(currentPlaylist[currentTrackIndex]);
    } else if (currentPlaylist.isNotEmpty) {
      // Ir al final de la lista
      currentTrackIndex = currentPlaylist.length - 1;
      await _playAudio(currentPlaylist[currentTrackIndex]);
    }
  }

  Future<void> _seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  // Funciones para selección de directorio con fallback para Linux
  Future<void> _selectDirectoryNative() async {
    try {
      String? selectedDirectory;
      if (Platform.isLinux) {
        selectedDirectory = await _pickDirectoryWithFallback();
      } else {
        selectedDirectory = await FilePicker.platform.getDirectoryPath();
      }

      if (selectedDirectory != null) {
        await _loadDirectoryContents(selectedDirectory);
      }
    } catch (e) {
      _showError('Error al seleccionar directorio: $e');
    }
  }

  Future<String?> _pickDirectoryWithFallback() async {
    final tools = ['zenity', 'kdialog', 'dialog', 'whiptail'];

    for (final tool in tools) {
      try {
        final result = await Process.run('which', [tool]);
        if ((result.stdout as String).trim().isNotEmpty) {
          final selectedPath = await _pickWithTool(tool);
          if (selectedPath != null) {
            return selectedPath;
          }
        }
      } catch (e) {
        debugPrint('Error verificando herramienta $tool: $e');
        continue;
      }
    }

    // Si no hay herramientas disponibles, mostrar diálogo manual
    return await _showManualPathDialog();
  }

  Future<String?> _pickWithTool(String tool) async {
    try {
      ProcessResult result;

      switch (tool) {
        case 'zenity':
          result = await Process.run('zenity', [
            '--file-selection',
            '--directory',
            '--title=Selecciona una carpeta de música',
          ]);
          if (result.exitCode == 0) {
            return (result.stdout as String).trim();
          }
          break;

        case 'kdialog':
          result = await Process.run('kdialog', [
            '--getexistingdirectory',
            Platform.environment['HOME'] ?? '.',
            '--title',
            'Selecciona una carpeta de música',
          ]);
          if (result.exitCode == 0) {
            return (result.stdout as String).trim();
          }
          break;

        case 'dialog':
        case 'whiptail':
          // Para dialog y whiptail, usamos inputbox
          result = await Process.run(tool, [
            '--inputbox',
            'Escribe el path del directorio:',
            '10',
            '50',
            Platform.environment['HOME'] ?? '.',
          ], stdoutEncoding: utf8);

          if (result.exitCode == 0) {
            final path = (result.stdout as String).trim();
            if (path.isNotEmpty && await Directory(path).exists()) {
              return path;
            }
          }
          break;
      }
    } catch (e) {
      debugPrint('Error usando herramienta $tool: $e');
    }

    return null;
  }

  Future<String?> _showManualPathDialog() async {
    TextEditingController pathController = TextEditingController(
      text: Platform.environment['HOME'] ?? '',
    );

    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleccionar directorio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No se encontraron herramientas de selección de archivos.\nEscribe la ruta del directorio manualmente:',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pathController,
                decoration: const InputDecoration(
                  labelText: 'Ruta del directorio',
                  hintText: '/home/usuario/Music',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                String path = pathController.text.trim();
                Navigator.of(context).pop(path.isNotEmpty ? path : null);
              },
              child: const Text('Seleccionar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToPath() async {
    TextEditingController pathController = TextEditingController(
      text: currentPath,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ir a directorio'),
          content: TextField(
            controller: pathController,
            decoration: InputDecoration(
              labelText: 'Ruta del directorio',
              hintText: Platform.isWindows
                  ? 'C:\\Users\\Usuario\\Music'
                  : Platform.isAndroid
                  ? '/storage/emulated/0/Music'
                  : '/home/usuario/Music',
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                String path = pathController.text.trim();
                if (path.isNotEmpty) {
                  _loadDirectoryContents(path);
                }
              },
              child: const Text('Ir'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToParentDirectory() async {
    if (currentPath.isNotEmpty) {
      Directory parent = Directory(currentPath).parent;
      await _loadDirectoryContents(parent.path);
    }
  }

  Widget _buildMusicPlayer() {
    if (currentlyPlaying == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Información de la canción
          Row(
            children: [
              const Icon(Icons.music_note, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentlyPlaying!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${currentTrackIndex + 1} de ${currentPlaylist.length}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Barra de progreso
          Row(
            children: [
              Text(
                _formatDuration(currentPosition),
                style: const TextStyle(fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: totalDuration.inMilliseconds > 0
                      ? currentPosition.inMilliseconds /
                            totalDuration.inMilliseconds
                      : 0.0,
                  onChanged: (value) {
                    final position = Duration(
                      milliseconds: (value * totalDuration.inMilliseconds)
                          .round(),
                    );
                    _seekTo(position);
                  },
                ),
              ),
              Text(
                _formatDuration(totalDuration),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Controles de reproducción
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: currentPlaylist.isNotEmpty ? _playPrevious : null,
              ),
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 32,
                ),
                onPressed: _pauseResume,
              ),
              IconButton(icon: const Icon(Icons.stop), onPressed: _stop),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: currentPlaylist.isNotEmpty ? _playNext : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Player Explorer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _selectDirectoryNative,
            tooltip: 'Seleccionar directorio',
          ),
          IconButton(
            icon: const Icon(Icons.edit_location),
            onPressed: _navigateToPath,
            tooltip: 'Ir a ruta específica',
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
          // Mostrar ruta actual
          if (currentPath.isNotEmpty)
            Container(
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.content_copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: currentPath));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ruta copiada al portapapeles'),
                        ),
                      );
                    },
                    tooltip: 'Copiar ruta',
                  ),
                ],
              ),
            ),

          // Mostrar contador de archivos
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Archivos de audio: ${audioFiles.whereType<File>().length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Directorios: ${audioFiles.whereType<Directory>().length}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          // Lista de archivos
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : audioFiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.music_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No se encontraron archivos de audio',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'en este directorio',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: audioFiles.length,
                    itemBuilder: (context, index) {
                      final entity = audioFiles[index];
                      final isDirectory = entity is Directory;
                      final fileName = _getFileName(entity.path);
                      final isCurrentTrack =
                          !isDirectory &&
                          currentlyPlaying != null &&
                          currentlyPlaying == fileName;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        color: isCurrentTrack
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: ListTile(
                          leading: Icon(
                            isDirectory
                                ? Icons.folder
                                : isCurrentTrack && isPlaying
                                ? Icons.volume_up
                                : Icons.music_note,
                            color: isDirectory
                                ? Colors.blue
                                : isCurrentTrack
                                ? Theme.of(context).colorScheme.primary
                                : Colors.green,
                          ),
                          title: Text(
                            fileName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isCurrentTrack
                                  ? FontWeight.bold
                                  : null,
                            ),
                          ),
                          subtitle: isDirectory
                              ? const Text('Directorio')
                              : FutureBuilder<FileStat>(
                                  future: entity.stat(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return Text(
                                        '${_getFileExtension(entity.path).toUpperCase()} • ${_formatFileSize(snapshot.data!.size)}',
                                      );
                                    }
                                    return const Text('Cargando...');
                                  },
                                ),
                          trailing: isDirectory
                              ? const Icon(Icons.chevron_right)
                              : isCurrentTrack
                              ? Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : const Icon(
                                  Icons.play_arrow,
                                  color: Colors.grey,
                                ),
                          onTap: () {
                            if (isDirectory) {
                              _loadDirectoryContents(entity.path);
                            } else {
                              if (isCurrentTrack && isPlaying) {
                                _pauseResume();
                              } else {
                                _playAudio(entity as File);
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),

          // Reproductor de música
          _buildMusicPlayer(),
        ],
      ),
    );
  }
}
