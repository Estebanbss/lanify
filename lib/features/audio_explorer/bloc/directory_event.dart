import 'package:equatable/equatable.dart';
import 'package:audio_service/audio_service.dart';

/// Eventos para el DirectoryBloc
abstract class DirectoryEvent extends Equatable {
  const DirectoryEvent();

  @override
  List<Object?> get props => [];
}

/// Cargar directorio específico
class LoadDirectory extends DirectoryEvent {
  final String path;

  const LoadDirectory(this.path);

  @override
  List<Object?> get props => [path];
}

/// Cargar directorio por defecto
class LoadDefaultDirectory extends DirectoryEvent {
  const LoadDefaultDirectory();
}

/// Recargar directorio actual
class ReloadCurrentDirectory extends DirectoryEvent {
  const ReloadCurrentDirectory();
}

/// Cambiar filtro de búsqueda
class ChangeSearchFilter extends DirectoryEvent {
  final String filter;

  const ChangeSearchFilter(this.filter);

  @override
  List<Object?> get props => [filter];
}

/// Alternar agrupación por artista
class ToggleGroupByArtist extends DirectoryEvent {
  const ToggleGroupByArtist();
}

/// Actualizar metadatos de un archivo específico
class UpdateMetadataForFile extends DirectoryEvent {
  final String filePath;
  final MediaItem metadata;

  const UpdateMetadataForFile(this.filePath, this.metadata);

  @override
  List<Object?> get props => [filePath, metadata];
}

/// Establecer archivo actual en reproducción
class SetCurrentlyPlaying extends DirectoryEvent {
  final String? filePath;

  const SetCurrentlyPlaying(this.filePath);

  @override
  List<Object?> get props => [filePath];
}
