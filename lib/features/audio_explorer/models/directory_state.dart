import 'package:equatable/equatable.dart';
import 'dart:io';
import 'audio_file_item.dart';

/// Estado del explorador de archivos
class DirectoryState extends Equatable {
  final String currentPath;
  final List<Directory> directories;
  final List<AudioFileItem> audioFiles;
  final bool isLoading;
  final String? error;
  final bool isGroupedByArtist;
  final String searchFilter;

  const DirectoryState({
    this.currentPath = '',
    this.directories = const [],
    this.audioFiles = const [],
    this.isLoading = false,
    this.error,
    this.isGroupedByArtist = false,
    this.searchFilter = '',
  });

  DirectoryState copyWith({
    String? currentPath,
    List<Directory>? directories,
    List<AudioFileItem>? audioFiles,
    bool? isLoading,
    String? error,
    bool? isGroupedByArtist,
    String? searchFilter,
    bool clearError = false,
  }) {
    return DirectoryState(
      currentPath: currentPath ?? this.currentPath,
      directories: directories ?? this.directories,
      audioFiles: audioFiles ?? this.audioFiles,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isGroupedByArtist: isGroupedByArtist ?? this.isGroupedByArtist,
      searchFilter: searchFilter ?? this.searchFilter,
    );
  }

  List<AudioFileItem> get filteredAudioFiles {
    if (searchFilter.isEmpty) return audioFiles;
    return audioFiles.where((file) =>
        file.fileName.toLowerCase().contains(searchFilter.toLowerCase()) ||
        file.artist.toLowerCase().contains(searchFilter.toLowerCase()) ||
        file.title.toLowerCase().contains(searchFilter.toLowerCase())
    ).toList();
  }

  List<Directory> get filteredDirectories {
    if (searchFilter.isEmpty) return directories;
    return directories.where((dir) =>
        dir.path.split(Platform.pathSeparator).last.toLowerCase()
            .contains(searchFilter.toLowerCase())
    ).toList();
  }

  Map<String, List<AudioFileItem>> get groupedByArtist {
    final Map<String, List<AudioFileItem>> groups = {};
    for (final file in filteredAudioFiles) {
      final artist = file.artist;
      groups.putIfAbsent(artist, () => []).add(file);
    }
    return groups;
  }

  @override
  List<Object?> get props => [
    currentPath,
    directories,
    audioFiles,
    isLoading,
    error,
    isGroupedByArtist,
    searchFilter,
  ];
}
