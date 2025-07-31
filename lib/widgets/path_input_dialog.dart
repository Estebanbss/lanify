import 'package:flutter/material.dart';

class PathInputDialog extends StatelessWidget {
  final TextEditingController controller;
  final String title;
  final String label;
  final String hint;
  final VoidCallback onSelect;

  const PathInputDialog({
    super.key,
    required this.controller,
    required this.title,
    required this.label,
    required this.hint,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        maxLines: 2,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(onPressed: onSelect, child: const Text('Seleccionar')),
      ],
    );
  }
}
