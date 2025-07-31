import 'package:flutter/material.dart';

class PermissionDialog extends StatelessWidget {
  final List<String> deniedPermissions;
  final VoidCallback onSettings;

  const PermissionDialog({
    super.key,
    required this.deniedPermissions,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Permisos necesarios'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'La aplicación necesita los siguientes permisos para funcionar correctamente:',
          ),
          const SizedBox(height: 8),
          ...deniedPermissions.map(
            (permission) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6),
                  const SizedBox(width: 8),
                  Expanded(child: Text(permission)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Puedes otorgar estos permisos desde la configuración de la aplicación.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onSettings();
          },
          child: const Text('Ir a configuración'),
        ),
      ],
    );
  }
}
