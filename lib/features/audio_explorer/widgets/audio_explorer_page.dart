import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../bloc/directory_bloc.dart';
import '../bloc/directory_event.dart';
import '../models/directory_state.dart';
import '../../audio_player/bloc/player_bloc.dart';
import '../../../core/di/service_locator.dart';
import '../../../shared/widgets/audio_stats_widget.dart';
import 'audio_file_list_view.dart';
import 'directory_navigation_bar.dart';
import 'search_bar_widget.dart';

/// Página principal del explorador de audio
class AudioExplorerPage extends StatelessWidget {
  const AudioExplorerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              getIt<DirectoryBloc>()..add(const LoadDefaultDirectory()),
        ),
        BlocProvider.value(value: getIt<PlayerBloc>()),
      ],
      child: const AudioExplorerView(),
    );
  }
}

class AudioExplorerView extends StatelessWidget {
  const AudioExplorerView({super.key});

  void _selectFile(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Archivo seleccionado: ${file.name}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar archivo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: const [Expanded(child: DirectoryNavigationBar())]),
        actions: [
          // Show file picker on web, directory picker on other platforms
          IconButton(
            icon: Icon(kIsWeb ? Icons.upload_file : Icons.folder_open),
            onPressed: () =>
                kIsWeb ? _selectFile(context) : _selectDirectory(context),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showStats(context),
          ),
          BlocBuilder<DirectoryBloc, DirectoryState>(
            builder: (context, state) {
              return IconButton(
                icon: Icon(
                  state.isGroupedByArtist ? Icons.list : Icons.group_work,
                ),
                onPressed: () {
                  context.read<DirectoryBloc>().add(
                    const ToggleGroupByArtist(),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SearchBarWidget(),
          Expanded(
            child: BlocBuilder<DirectoryBloc, DirectoryState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${state.error}',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.read<DirectoryBloc>().add(
                              LoadDirectory(state.currentPath),
                            );
                          },
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                return const AudioFileListView();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _selectDirectory(BuildContext context) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        if (context.mounted) {
          context.read<DirectoryBloc>().add(LoadDirectory(selectedDirectory));
        }
      }
    } catch (e) {
      if (context.mounted) {
        final isUnimplemented =
            e.toString().contains('UnimplementedError') ||
            e.toString().contains('has not been implemented');
        final errorMsg = isUnimplemented
            ? 'Seleccionar directorio no está disponible en esta plataforma.'
            : 'Error al seleccionar directorio: $e';
        debugPrint(errorMsg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showStats(BuildContext context) {
    final state = context.read<DirectoryBloc>().state;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: AudioStatsWidget(audioFiles: state.audioFiles),
        ),
      ),
    );
  }
}
