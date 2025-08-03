import 'package:get_it/get_it.dart';
import 'package:audio_service/audio_service.dart';
import '../../core/services/directory_service.dart';
import '../../core/services/metadata_service.dart';
import '../../core/services/audio_handler.dart';
import '../../features/audio_explorer/bloc/directory_bloc.dart';
import '../../features/audio_player/bloc/player_bloc.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // AudioHandler (debe ser inicializado primero)
  final audioHandler = await AudioService.init(
    builder: () => LanifyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.lanify.audio',
      androidNotificationChannelName: 'Lanify Audio',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
    ),
  );
  getIt.registerSingleton<LanifyAudioHandler>(audioHandler);

  // Services
  getIt.registerLazySingleton<DirectoryService>(() => DirectoryService());
  getIt.registerLazySingleton<MetadataService>(() => MetadataService());

  // BLoCs
  getIt.registerFactory<DirectoryBloc>(
    () => DirectoryBloc(
      directoryService: getIt<DirectoryService>(),
      metadataService: getIt<MetadataService>(),
    ),
  );

  getIt.registerLazySingleton<PlayerBloc>(
    () => PlayerBloc(audioHandler: getIt<LanifyAudioHandler>()),
  );
}
