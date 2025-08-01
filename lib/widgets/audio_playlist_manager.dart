import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:io';
import 'audio_handler.dart';
import 'audio_utils.dart';

/// Manages audio playlist and queue state
class AudioPlaylistManager extends ChangeNotifier {
  static final AudioPlaylistManager _instance =
      AudioPlaylistManager._internal();
  factory AudioPlaylistManager() => _instance;
  AudioPlaylistManager._internal();

  // Estado de la playlist
  List<File> _currentPlaylist = [];
  List<MediaItem> _currentMediaItems = [];
  String? _currentlyPlaying;
  int _currentTrackIndex = -1;

  // Referencia al audio handler
  MyAudioHandler? _audioHandler;

  // Getters
  List<File> get currentPlaylist => List.unmodifiable(_currentPlaylist);
  List<MediaItem> get currentMediaItems =>
      List.unmodifiable(_currentMediaItems);
  String? get currentlyPlaying =>
      _currentlyPlaying != null ? getFileName(_currentlyPlaying!) : null;
  int get currentTrackIndex => _currentTrackIndex;

  /// Inicializa el manager con el audio handler
  void initialize(MyAudioHandler audioHandler) {
    _audioHandler = audioHandler;
    debugPrint('AudioPlaylistManager: Inicializado con audio handler');
  }

  /// Actualiza la playlist completa
  void updatePlaylist(List<File> playlist, List<MediaItem> mediaItems) {
    debugPrint(
      'AudioPlaylistManager: Actualizando playlist con ${playlist.length} elementos',
    );

    _currentPlaylist = List.from(playlist);
    _currentMediaItems = List.from(mediaItems);

    // Actualizar queue en el audio handler
    _audioHandler?.updateQueue(_currentMediaItems);

    notifyListeners();
  }

  /// Establece la canción actual usando el path completo del archivo
  void setCurrentTrack(String? filePath, int index) {
    debugPrint(
      'AudioPlaylistManager: Estableciendo canción actual: $filePath (índice: $index)',
    );

    _currentlyPlaying = filePath;
    _currentTrackIndex = index;

    // Actualizar índice en el audio handler
    if (index >= 0 && index < _currentMediaItems.length) {
      _audioHandler?.updateCurrentIndex(index);
    }

    notifyListeners();
  }

  /// Maneja el renombrado de archivos actualizando referencias
  void handleFileRename(
    String oldPath,
    String newPath,
    MediaItem updatedMediaItem,
  ) {
    debugPrint('AudioPlaylistManager.handleFileRename: $oldPath -> $newPath');

    try {
      // Buscar el archivo en la playlist
      int trackIndex = findTrackIndex(oldPath);
      if (trackIndex == -1) {
        debugPrint(
          'AudioPlaylistManager: Archivo no encontrado en playlist: $oldPath',
        );
        return;
      }

      debugPrint(
        'AudioPlaylistManager: Archivo encontrado en índice: $trackIndex',
      );

      // Actualizar el archivo en la playlist
      final newFile = File(newPath);
      _currentPlaylist[trackIndex] = newFile;

      // Actualizar el MediaItem correspondiente
      _currentMediaItems[trackIndex] = updatedMediaItem;

      // Si es el archivo actualmente en reproducción, actualizar la referencia
      if (_currentlyPlaying == oldPath) {
        debugPrint(
          'AudioPlaylistManager: Actualizando currentlyPlaying: $oldPath -> $newPath',
        );
        _currentlyPlaying = newPath;
      }

      // Actualizar la queue en el audio handler
      _audioHandler?.updateQueue(_currentMediaItems);

      // Si es el item actual, actualizarlo también en el audio handler
      if (trackIndex == _currentTrackIndex) {
        debugPrint(
          'AudioPlaylistManager: Actualizando item actual en audio handler',
        );
        _audioHandler?.updateMediaItemAt(trackIndex, updatedMediaItem);
      }

      notifyListeners();
      debugPrint('AudioPlaylistManager: Renombrado completado exitosamente');
    } catch (e) {
      debugPrint('AudioPlaylistManager.handleFileRename: Error: $e');
    }
  }

  /// Encuentra el índice de un archivo en la playlist
  int findTrackIndex(String filePath) {
    for (int i = 0; i < _currentPlaylist.length; i++) {
      if (_currentPlaylist[i].path == filePath) {
        return i;
      }
    }
    return -1;
  }

  /// Encuentra el índice de un MediaItem en la lista
  int findMediaItemIndex(String filePath) {
    for (int i = 0; i < _currentMediaItems.length; i++) {
      if (_currentMediaItems[i].id == filePath) {
        return i;
      }
    }
    return -1;
  }

  /// Limpia la playlist
  void clearPlaylist() {
    debugPrint('AudioPlaylistManager: Limpiando playlist');

    _currentPlaylist.clear();
    _currentMediaItems.clear();
    _currentlyPlaying = null;
    _currentTrackIndex = -1;

    _audioHandler?.updateQueue([]);

    notifyListeners();
  }

  /// Remueve un archivo de la playlist
  void removeFile(String filePath) {
    debugPrint(
      'AudioPlaylistManager: Removiendo archivo de playlist: $filePath',
    );

    final fileIndex = findTrackIndex(filePath);
    final mediaIndex = findMediaItemIndex(filePath);

    bool updated = false;

    if (fileIndex >= 0) {
      _currentPlaylist.removeAt(fileIndex);
      updated = true;

      // Ajustar índice actual si es necesario
      if (_currentTrackIndex > fileIndex) {
        _currentTrackIndex--;
      } else if (_currentTrackIndex == fileIndex) {
        // La canción actual fue removida
        _currentlyPlaying = null;
        _currentTrackIndex = -1;
      }
    }

    if (mediaIndex >= 0) {
      _currentMediaItems.removeAt(mediaIndex);
      updated = true;
    }

    if (updated) {
      _audioHandler?.updateQueue(_currentMediaItems);
      notifyListeners();
    }
  }

  /// Obtiene estadísticas de la playlist
  Map<String, dynamic> getPlaylistStats() {
    return {
      'totalFiles': _currentPlaylist.length,
      'totalMediaItems': _currentMediaItems.length,
      'currentTrackIndex': _currentTrackIndex,
      'currentlyPlaying': _currentlyPlaying,
      'hasAudioHandler': _audioHandler != null,
    };
  }
}
