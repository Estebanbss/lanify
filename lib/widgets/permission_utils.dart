import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'permission_dialog.dart';

Future<bool> isAndroid13OrHigher() async {
  if (Platform.isAndroid) {
    var androidInfo = await DeviceInfoPlugin().androidInfo;
    return androidInfo.version.sdkInt >= 33;
  }
  return false;
}

Future<void> requestPermissions(BuildContext context) async {
  if (Platform.isAndroid) {
    List<Permission> permissionsToRequest = [];
    if (await isAndroid13OrHigher()) {
      permissionsToRequest.addAll([Permission.audio, Permission.notification]);
    } else {
      permissionsToRequest.addAll([
        Permission.storage,
        Permission.manageExternalStorage,
      ]);
    }
    Map<Permission, PermissionStatus> permissions = await permissionsToRequest
        .request();
    bool allGranted = permissions.values.every(
      (status) =>
          status == PermissionStatus.granted ||
          status == PermissionStatus.limited,
    );
    if (!allGranted) {
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
      if (deniedPermissions.isNotEmpty && context.mounted) {
        showDialog(
          context: context,
          builder: (context) => PermissionDialog(
            deniedPermissions: deniedPermissions,
            onSettings: openAppSettings,
          ),
        );
      }
    }
  }
}
