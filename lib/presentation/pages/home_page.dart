import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/service_locator.dart';
import '../../features/audio_explorer/bloc/directory_bloc.dart';
import '../../features/audio_player/bloc/player_bloc.dart';
import '../../features/audio_explorer/widgets/audio_explorer_page.dart';
import '../widgets/player/player_controls.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => getIt<DirectoryBloc>()),
        BlocProvider.value(value: getIt<PlayerBloc>()),
      ],
      child: Scaffold(
        body: const Column(
          children: [
            Expanded(child: AudioExplorerPage()),
            PlayerControls(),
          ],
        ),
      ),
    );
  }
}
