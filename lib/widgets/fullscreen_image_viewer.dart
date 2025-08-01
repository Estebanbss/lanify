import 'package:flutter/material.dart';
import 'dart:io';

/// Widget para mostrar imágenes en pantalla completa con zoom
class FullscreenImageViewer extends StatefulWidget {
  final String imagePath;
  final String? title;

  const FullscreenImageViewer({super.key, required this.imagePath, this.title});

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        foregroundColor: Colors.white,
        title: widget.title != null
            ? Text(widget.title!, style: const TextStyle(color: Colors.white))
            : const Text(
                'Carátula del álbum',
                style: TextStyle(color: Colors.white),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            onPressed: _resetZoom,
            tooltip: 'Restablecer zoom',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20.0),
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(
            File(widget.imagePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 64, color: Colors.white54),
                    SizedBox(height: 16),
                    Text(
                      'No se pudo cargar la imagen',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _resetZoom,
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        foregroundColor: Colors.white,
        child: const Icon(Icons.zoom_out_map),
      ),
    );
  }
}

/// Función auxiliar para mostrar la imagen en pantalla completa
void showFullscreenImage(
  BuildContext context,
  String imagePath, {
  String? title,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) =>
          FullscreenImageViewer(imagePath: imagePath, title: title),
    ),
  );
}
