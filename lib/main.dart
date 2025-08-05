import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/di/service_locator.dart';
import 'presentation/pages/home_page.dart';

void main() async {
  // Manejo global de errores verboso
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('FLUTTER ERROR: ${details.exception}');
    debugPrint('STACKTRACE: ${details.stack}');
    FlutterError.presentError(details);
  };

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await setupServiceLocator();
      await _requestPermissions();
      runApp(const LanifyApp());
    },
    (error, stack) {
      debugPrint('ZONE ERROR: $error');
      debugPrint('STACKTRACE: $stack');
    },
  );
}

Future<void> _requestPermissions() async {
  try {
    // Solo pedir permisos en Android/iOS - Linux no los necesita
    if (kIsWeb) {
      debugPrint('Permisos no requeridos en web.');
      return;
    }

    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      debugPrint('Permisos no requeridos en plataformas de escritorio.');
      return;
    }

    // Solo para Android/iOS
    if (Platform.isAndroid) {
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
    }
    // Para iOS se pueden agregar permisos específicos si es necesario
  } catch (e) {
    debugPrint('Error al solicitar permisos (ignorado): $e');
  }
}

class LanifyApp extends StatelessWidget {
  const LanifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lanify',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2C3E50)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C3E50),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
