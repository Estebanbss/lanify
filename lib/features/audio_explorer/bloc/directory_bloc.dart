import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';

import '../models/directory_state.dart';
import '../models/audio_file_item.dart';
import 'directory_event.dart';
import '../../../core/services/directory_service.dart';
import '../../../core/services/metadata_service.dart';

/// BLoC para manejar el estado del explorador de directorios
class DirectoryBloc extends Bloc<DirectoryEvent, DirectoryState> {
  final DirectoryService _directoryService;
  final MetadataService _metadataService;

  StreamSubscription<FileSystemEvent>? _directoryWatcher;
  StreamSubscription<MediaItem>? _metadataSubscription;

  DirectoryBloc({
    required DirectoryService directoryService,
    required MetadataService metadataService,
  }) : _directoryService = directoryService,
       _metadataService = metadataService,
       super(const DirectoryState()) {
    on<LoadDefaultDirectory>(_onLoadDefaultDirectory);
    on<LoadDirectory>(_onLoadDirectory);
    on<ReloadCurrentDirectory>(_onReloadCurrentDirectory);
    on<ChangeSearchFilter>(_onChangeSearchFilter);
    on<ToggleGroupByArtist>(_onToggleGroupByArtist);
    on<UpdateMetadataForFile>(_onUpdateMetadataForFile);
    on<SetCurrentlyPlaying>(_onSetCurrentlyPlaying);
  }

  /// Carga el directorio por defecto
  Future<void> _onLoadDefaultDirectory(
    LoadDefaultDirectory event,
    Emitter<DirectoryState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true, clearError: true));

      final defaultDir = await _directoryService.getDefaultMusicDirectory();
      add(LoadDirectory(defaultDir.path));
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Error cargando directorio por defecto: $e',
        ),
      );
    }
  }

  /// Carga un directorio específico
  Future<void> _onLoadDirectory(
    LoadDirectory event,
    Emitter<DirectoryState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true, clearError: true));

      // Cancelar watcher anterior
      await _directoryWatcher?.cancel();
      await _metadataSubscription?.cancel();

      // Cargar contenido del directorio
      final contents = await _directoryService.loadDirectoryContents(
        event.path,
      );

      // Crear items de audio iniciales sin metadatos
      final initialAudioFiles = contents.audioFiles
          .map((file) => AudioFileItem(file: file))
          .toList();

      emit(
        state.copyWith(
          currentPath: event.path,
          directories: contents.directories,
          audioFiles: initialAudioFiles,
          isLoading: false,
        ),
      );

      // Configurar watcher para cambios en el directorio
      _setupDirectoryWatcher(event.path);

      // Cargar metadatos en background
      _loadMetadataInBackground(contents.audioFiles);
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Error cargando directorio: $e',
        ),
      );
    }
  }

  /// Recarga el directorio actual
  Future<void> _onReloadCurrentDirectory(
    ReloadCurrentDirectory event,
    Emitter<DirectoryState> emit,
  ) async {
    if (state.currentPath.isNotEmpty) {
      add(LoadDirectory(state.currentPath));
    }
  }

  /// Cambia el filtro de búsqueda
  void _onChangeSearchFilter(
    ChangeSearchFilter event,
    Emitter<DirectoryState> emit,
  ) {
    emit(state.copyWith(searchFilter: event.filter));
  }

  /// Alterna la agrupación por artista
  void _onToggleGroupByArtist(
    ToggleGroupByArtist event,
    Emitter<DirectoryState> emit,
  ) {
    emit(state.copyWith(isGroupedByArtist: !state.isGroupedByArtist));
  }

  /// Actualiza los metadatos de un archivo específico
  void _onUpdateMetadataForFile(
    UpdateMetadataForFile event,
    Emitter<DirectoryState> emit,
  ) {
    final updatedFiles = state.audioFiles.map((audioFile) {
      if (audioFile.file.path == event.filePath) {
        // Extraer la ruta del artwork desde metadata.artUri si está disponible
        String? artworkPath;
        if (event.metadata.artUri != null) {
          try {
            artworkPath = event.metadata.artUri!.toFilePath();
          } catch (e) {
            debugPrint('Error extracting artwork path: $e');
          }
        }

        return audioFile.copyWith(
          metadata: event.metadata,
          artworkPath: artworkPath,
        );
      }
      return audioFile;
    }).toList();

    emit(state.copyWith(audioFiles: updatedFiles));
  }

  /// Establece el archivo actualmente en reproducción
  void _onSetCurrentlyPlaying(
    SetCurrentlyPlaying event,
    Emitter<DirectoryState> emit,
  ) {
    final updatedFiles = state.audioFiles.map((audioFile) {
      return audioFile.copyWith(
        isCurrentlyPlaying: audioFile.file.path == event.filePath,
      );
    }).toList();

    emit(state.copyWith(audioFiles: updatedFiles));
  }

  /// Configura el watcher para monitorear cambios en el directorio
  void _setupDirectoryWatcher(String path) {
    _directoryWatcher = _directoryService
        .watchDirectory(path)
        .listen(
          (event) {
            debugPrint(
              'DirectoryBloc: Cambio detectado en directorio: ${event.path}',
            );
            // Recargar directorio cuando hay cambios
            Future.delayed(const Duration(milliseconds: 500), () {
              add(const ReloadCurrentDirectory());
            });
          },
          onError: (error) {
            debugPrint('DirectoryBloc: Error en watcher: $error');
          },
        );
  }

  /// Carga metadatos en background usando stream
  void _loadMetadataInBackground(List<File> files) {
    debugPrint(
      'DirectoryBloc: Iniciando carga de metadatos para ${files.length} archivos',
    );

    _metadataSubscription = _metadataService
        .loadMetadataStream(files)
        .listen(
          (metadata) {
            // Usar evento en lugar de emit directo
            add(UpdateMetadataForFile(metadata.id, metadata));
          },
          onError: (error) {
            debugPrint('DirectoryBloc: Error cargando metadatos: $error');
          },
          onDone: () {
            debugPrint('DirectoryBloc: Carga de metadatos completada');
          },
        );
  }

  @override
  Future<void> close() {
    _directoryWatcher?.cancel();
    _metadataSubscription?.cancel();
    return super.close();
  }
}
