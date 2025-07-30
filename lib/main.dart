import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';

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
    _initializeAudioPlayer();
    _requestPermissions();
  }

  void _initializeAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      setState(() {
        isPlaying = state == PlayerState.playing;
        isPaused = state == PlayerState.paused;
      });
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
      if (await Permission.audio.isDenied) {
        await Permission.audio.request();
      }
    }
    _loadDefaultDirectory();
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
      currentTrackIndex = currentPlaylist.indexOf(audioFile);
      await _audioPlayer.play(DeviceFileSource(audioFile.path));
      setState(() {
        currentlyPlaying = _getFileName(audioFile.path);
      });
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
  }

  Future<void> _stop() async {
    await _audioPlayer.stop();
    setState(() {
      currentlyPlaying = null;
      currentPosition = Duration.zero;
      totalDuration = Duration.zero;
      currentTrackIndex = -1;
    });
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

  void _showDirectorySelector() {
    List<DirectoryOption> options = [];

    if (Platform.isLinux) {
      String home = Platform.environment['HOME'] ?? '/home';
      options = [
        DirectoryOption('Directorio Home', home, Icons.home),
        DirectoryOption('Música', '$home/Music', Icons.music_note),
        DirectoryOption('Descargas', '$home/Downloads', Icons.download),
        DirectoryOption('Documentos', '$home/Documents', Icons.description),
        DirectoryOption('Escritorio', '$home/Desktop', Icons.desktop_windows),
        DirectoryOption('Videos', '$home/Videos', Icons.video_library),
        DirectoryOption('Raíz del sistema', '/', Icons.folder),
        DirectoryOption('Media', '/media', Icons.storage),
        DirectoryOption('Mnt', '/mnt', Icons.storage),
      ];
    } else if (Platform.isWindows) {
      String userProfile = Platform.environment['USERPROFILE'] ?? '';
      options = [
        DirectoryOption('Música', '$userProfile\\Music', Icons.music_note),
        DirectoryOption('Descargas', '$userProfile\\Downloads', Icons.download),
        DirectoryOption(
          'Documentos',
          '$userProfile\\Documents',
          Icons.description,
        ),
        DirectoryOption(
          'Escritorio',
          '$userProfile\\Desktop',
          Icons.desktop_windows,
        ),
        DirectoryOption('Videos', '$userProfile\\Videos', Icons.video_library),
        DirectoryOption('Disco C:', 'C:\\', Icons.storage),
        DirectoryOption('Disco D:', 'D:\\', Icons.storage),
        DirectoryOption('Usuario', userProfile, Icons.person),
      ];
    } else if (Platform.isAndroid) {
      options = [
        DirectoryOption(
          'Música',
          '/storage/emulated/0/Music',
          Icons.music_note,
        ),
        DirectoryOption(
          'Descargas',
          '/storage/emulated/0/Download',
          Icons.download,
        ),
        DirectoryOption('DCIM', '/storage/emulated/0/DCIM', Icons.camera_alt),
        DirectoryOption(
          'Documentos',
          '/storage/emulated/0/Documents',
          Icons.description,
        ),
        DirectoryOption(
          'Almacenamiento interno',
          '/storage/emulated/0/',
          Icons.storage,
        ),
        DirectoryOption('Tarjeta SD', '/storage/sdcard1/', Icons.sd_card),
      ];
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleccionar directorio'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                return ListTile(
                  leading: Icon(option.icon),
                  title: Text(option.name),
                  subtitle: Text(option.path),
                  onTap: () {
                    Navigator.of(context).pop();
                    _loadDirectoryContents(option.path);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
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

  void _showQuickNavigation() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Navegación rápida',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickNavButton(Icons.home, 'Home', () {
                    Navigator.pop(context);
                    if (Platform.isLinux) {
                      _loadDirectoryContents(
                        Platform.environment['HOME'] ?? '/',
                      );
                    } else if (Platform.isWindows) {
                      _loadDirectoryContents(
                        Platform.environment['USERPROFILE'] ?? 'C:\\',
                      );
                    } else if (Platform.isAndroid) {
                      _loadDirectoryContents('/storage/emulated/0/');
                    }
                  }),
                  _buildQuickNavButton(Icons.music_note, 'Música', () {
                    Navigator.pop(context);
                    if (Platform.isLinux) {
                      String home = Platform.environment['HOME'] ?? '/';
                      _loadDirectoryContents('$home/Music');
                    } else if (Platform.isWindows) {
                      String userProfile =
                          Platform.environment['USERPROFILE'] ?? '';
                      _loadDirectoryContents('$userProfile\\Music');
                    } else if (Platform.isAndroid) {
                      _loadDirectoryContents('/storage/emulated/0/Music');
                    }
                  }),
                  _buildQuickNavButton(Icons.download, 'Descargas', () {
                    Navigator.pop(context);
                    if (Platform.isLinux) {
                      String home = Platform.environment['HOME'] ?? '/';
                      _loadDirectoryContents('$home/Downloads');
                    } else if (Platform.isWindows) {
                      String userProfile =
                          Platform.environment['USERPROFILE'] ?? '';
                      _loadDirectoryContents('$userProfile\\Downloads');
                    } else if (Platform.isAndroid) {
                      _loadDirectoryContents('/storage/emulated/0/Download');
                    }
                  }),
                  _buildQuickNavButton(Icons.storage, 'Raíz', () {
                    Navigator.pop(context);
                    if (Platform.isLinux) {
                      _loadDirectoryContents('/');
                    } else if (Platform.isWindows) {
                      _loadDirectoryContents('C:\\');
                    } else if (Platform.isAndroid) {
                      _loadDirectoryContents('/storage/emulated/0/');
                    }
                  }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickNavButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: Theme.of(context).primaryColor),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
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
            onPressed: _showDirectorySelector,
            tooltip: 'Seleccionar directorio',
          ),
          IconButton(
            icon: const Icon(Icons.edit_location),
            onPressed: _navigateToPath,
            tooltip: 'Ir a ruta específica',
          ),
          IconButton(
            icon: const Icon(Icons.speed),
            onPressed: _showQuickNavigation,
            tooltip: 'Navegación rápida',
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

class DirectoryOption {
  final String name;
  final String path;
  final IconData icon;

  DirectoryOption(this.name, this.path, this.icon);
}
