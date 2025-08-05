import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_service/audio_service.dart' as audio_service;

import '../models/audio_file_item.dart';
import '../bloc/directory_bloc.dart';
import '../bloc/directory_event.dart';
import '../../../core/services/metadata_writer_service.dart';

class EditMetadataDialog extends StatefulWidget {
  final AudioFileItem audioFile;

  const EditMetadataDialog({super.key, required this.audioFile});

  @override
  State<EditMetadataDialog> createState() => _EditMetadataDialogState();
}

class _EditMetadataDialogState extends State<EditMetadataDialog> {
  late TextEditingController titleController;
  late TextEditingController artistController;
  late TextEditingController albumController;
  late TextEditingController fileNameController;
  late TextEditingController yearController;
  late TextEditingController genreController;
  late TextEditingController trackNumberController;
  late TextEditingController albumArtistController;
  late TextEditingController composerController;
  late TextEditingController lyricsController;
  late Map<String, TextEditingController> extraControllers;
  late Map<String, TextEditingController> customControllers;
  bool _isLoading = false;
  final _customMetadataKeyController = TextEditingController();
  final _customMetadataValueController = TextEditingController();

  // Variables para artwork
  Uint8List? _newArtworkBytes;
  String? _newArtworkPath;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.audioFile.title);
    artistController = TextEditingController(text: widget.audioFile.artist);
    albumController = TextEditingController(text: widget.audioFile.album);
    fileNameController = TextEditingController(text: widget.audioFile.fileName);

    // Inicializar controladores para metadatos estándar
    yearController = TextEditingController(
      text: _getMetadataValue('year') ?? '',
    );
    genreController = TextEditingController(
      text: _getMetadataValue('genre') ?? '',
    );
    trackNumberController = TextEditingController(
      text: _getMetadataValue('track') ?? '',
    );
    albumArtistController = TextEditingController(
      text: _getMetadataValue('albumArtist') ?? '',
    );
    composerController = TextEditingController(
      text: _getMetadataValue('composer') ?? '',
    );
    lyricsController = TextEditingController(
      text: _getMetadataValue('lyrics') ?? '',
    );

    // Inicializar controladores para metadatos extra existentes
    extraControllers = {};
    customControllers = {};

    if (widget.audioFile.metadata?.extras != null) {
      widget.audioFile.metadata!.extras!.forEach((key, value) {
        if (!_isSystemMetadata(key) && !_isStandardMetadata(key)) {
          extraControllers[key] = TextEditingController(
            text: value?.toString() ?? '',
          );
        }
      });
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    artistController.dispose();
    albumController.dispose();
    fileNameController.dispose();
    yearController.dispose();
    genreController.dispose();
    trackNumberController.dispose();
    albumArtistController.dispose();
    composerController.dispose();
    lyricsController.dispose();
    _customMetadataKeyController.dispose();
    _customMetadataValueController.dispose();

    for (final controller in extraControllers.values) {
      controller.dispose();
    }
    for (final controller in customControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit, color: Colors.blue),
          const SizedBox(width: 8),
          const Text('Edit Song'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showMetadataServiceInfo,
            tooltip: 'Información del servicio de metadatos',
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Imagen de portada con opción de cambiar
            _buildArtworkSection(),

            // Campos principales
            _buildTextField('Título', titleController),
            _buildTextField('Artista', artistController),
            _buildTextField('Álbum', albumController),
            _buildTextField('Artista del álbum', albumArtistController),
            _buildTextField('Año', yearController, TextInputType.number),
            _buildTextField('Género', genreController),
            _buildTextField(
              'Número de pista',
              trackNumberController,
              TextInputType.number,
            ),
            _buildTextField('Compositor', composerController),
            _buildTextField('Nombre de archivo', fileNameController),

            // Campo de letras (más grande)
            _buildLyricsField(),

            // Metadatos extra editables existentes
            if (extraControllers.isNotEmpty) ...[
              const Divider(),
              const Text(
                'Metadatos adicionales:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...extraControllers.entries.map(
                (entry) => _buildTextField(entry.key, entry.value),
              ),
            ],

            // Metadatos personalizados
            if (customControllers.isNotEmpty) ...[
              const Divider(),
              const Text(
                'Metadatos personalizados:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...customControllers.entries.map(
                (entry) => _buildCustomMetadataField(entry.key, entry.value),
              ),
            ],

            // Sección para agregar metadatos personalizados
            const Divider(),
            _buildAddCustomMetadataSection(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveChanges,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _buildArtworkSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildArtworkImage(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _selectNewArtwork,
                icon: const Icon(Icons.image),
                label: const Text('Cambiar portada'),
              ),
              if (_newArtworkBytes != null || _newArtworkPath != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _removeNewArtwork,
                  icon: const Icon(Icons.clear),
                  label: const Text('Quitar cambios'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkImage() {
    // Si hay nueva imagen seleccionada, mostrarla
    if (_newArtworkBytes != null) {
      return Image.memory(
        _newArtworkBytes!,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 60),
      );
    }

    // Si hay nueva ruta seleccionada, mostrarla
    if (_newArtworkPath != null) {
      return Image.file(
        File(_newArtworkPath!),
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 60),
      );
    }

    // Si hay artwork existente, mostrarlo
    if (widget.audioFile.effectiveArtworkPath != null) {
      return Image.file(
        File(widget.audioFile.effectiveArtworkPath!),
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 60),
      );
    }

    // Si no hay artwork, mostrar placeholder
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.music_note, size: 60),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, [
    TextInputType? inputType,
  ]) {
    // Validación especial para el campo de nombre de archivo
    String? helperText;
    if (label == 'Nombre de archivo') {
      final extension = widget.audioFile.file.path.split('.').last;
      helperText =
          'Se guardará como: ${controller.text.trim().isEmpty ? widget.audioFile.fileName : controller.text.trim()}.$extension';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          helperText: helperText,
          helperMaxLines: 2,
        ),
        onChanged: label == 'Nombre de archivo'
            ? (value) {
                // Forzar rebuild para actualizar el helper text
                setState(() {});
              }
            : null,
      ),
    );
  }

  Widget _buildLyricsField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: lyricsController,
        maxLines: 6,
        decoration: const InputDecoration(
          labelText: 'Letra de la canción',
          border: OutlineInputBorder(),
          alignLabelWithHint: true,
          hintText: 'Escribe aquí la letra de la canción...',
        ),
      ),
    );
  }

  Widget _buildCustomMetadataField(
    String key,
    TextEditingController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: key,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle, color: Colors.red),
            onPressed: () => _removeCustomMetadata(key),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCustomMetadataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Agregar metadato personalizado:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _customMetadataKeyController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                  hintText: 'ej: comentario, disco, etc.',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _customMetadataValueController,
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: _addCustomMetadata,
            ),
          ],
        ),
      ],
    );
  }

  void _selectNewArtwork() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _newArtworkBytes = file.bytes;
            _newArtworkPath = null;
          });
        } else if (file.path != null) {
          setState(() {
            _newArtworkPath = file.path;
            _newArtworkBytes = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Error selecting artwork: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeNewArtwork() {
    setState(() {
      _newArtworkBytes = null;
      _newArtworkPath = null;
    });
  }

  void _saveChanges() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Validar que al menos un campo tenga contenido
      if (titleController.text.trim().isEmpty &&
          artistController.text.trim().isEmpty &&
          albumController.text.trim().isEmpty) {
        throw Exception('Debe llenar al menos el título, artista o álbum');
      }

      File workingFile = widget.audioFile.file;

      // Renombrar archivo si es necesario
      if (fileNameController.text.trim().isNotEmpty &&
          fileNameController.text.trim() != widget.audioFile.fileName) {
        await _renameFile(fileNameController.text.trim());
        // Actualizar la referencia al archivo después del renombre
        final directory = widget.audioFile.file.parent;
        final extension = widget.audioFile.file.path.split('.').last;
        final newPath =
            '${directory.path}/${fileNameController.text.trim()}.$extension';
        workingFile = File(newPath);
      }

      // Crear los metadatos actualizados
      final Map<String, dynamic> updatedExtras = Map.from(
        widget.audioFile.metadata?.extras ?? {},
      );

      // Actualizar metadatos estándar
      if (yearController.text.trim().isNotEmpty) {
        updatedExtras['year'] = yearController.text.trim();
      }
      if (genreController.text.trim().isNotEmpty) {
        updatedExtras['genre'] = genreController.text.trim();
      }
      if (trackNumberController.text.trim().isNotEmpty) {
        updatedExtras['track'] = trackNumberController.text.trim();
      }
      if (albumArtistController.text.trim().isNotEmpty) {
        updatedExtras['albumArtist'] = albumArtistController.text.trim();
      }
      if (composerController.text.trim().isNotEmpty) {
        updatedExtras['composer'] = composerController.text.trim();
      }
      if (lyricsController.text.trim().isNotEmpty) {
        updatedExtras['lyrics'] = lyricsController.text.trim();
      }

      // Agregar metadatos personalizados y extra
      for (final entry in customControllers.entries) {
        if (entry.value.text.trim().isNotEmpty) {
          updatedExtras[entry.key] = entry.value.text.trim();
        }
      }
      for (final entry in extraControllers.entries) {
        if (entry.value.text.trim().isNotEmpty) {
          updatedExtras[entry.key] = entry.value.text.trim();
        }
      }

      // Crear el MediaItem actualizado
      String? newArtworkPath = widget.audioFile.metadata?.artUri?.toString();

      // Si se seleccionó nuevo artwork, guardarlo como archivo
      if (_newArtworkBytes != null) {
        try {
          final artworkDir = Directory('${workingFile.parent.path}/.artwork');
          if (!await artworkDir.exists()) {
            await artworkDir.create();
          }

          final fileName = workingFile.path.split('/').last.split('.').first;
          final artworkFile = File(
            '${artworkDir.path}/${fileName}_artwork.jpg',
          );
          await artworkFile.writeAsBytes(_newArtworkBytes!);
          newArtworkPath = artworkFile.path;
          debugPrint('Artwork guardado en: $newArtworkPath');
        } catch (e) {
          debugPrint('Error guardando artwork: $e');
          // Continuar sin artwork si hay error
        }
      } else if (_newArtworkPath != null) {
        newArtworkPath = _newArtworkPath;
      }

      final updatedMetadata = audio_service.MediaItem(
        id: workingFile.path,
        title: titleController.text.trim().isNotEmpty
            ? titleController.text.trim()
            : widget.audioFile.title,
        artist: artistController.text.trim().isNotEmpty
            ? artistController.text.trim()
            : widget.audioFile.artist,
        album: albumController.text.trim().isNotEmpty
            ? albumController.text.trim()
            : widget.audioFile.album,
        duration: widget.audioFile.duration,
        artUri: newArtworkPath != null
            ? Uri.file(newArtworkPath)
            : widget.audioFile.metadata?.artUri,
        extras: updatedExtras,
      );

      // Escribir metadatos al archivo usando el servicio robusto
      bool metadataWritten = false;
      try {
        // Preparar metadatos personalizados
        final Map<String, String> customMeta = {};
        for (final entry in customControllers.entries) {
          if (entry.value.text.trim().isNotEmpty) {
            customMeta[entry.key] = entry.value.text.trim();
          }
        }
        for (final entry in extraControllers.entries) {
          if (entry.value.text.trim().isNotEmpty) {
            customMeta[entry.key] = entry.value.text.trim();
          }
        }

        metadataWritten = await MetadataWriterService.writeMetadata(
          audioFile: workingFile,
          title: titleController.text.trim().isNotEmpty
              ? titleController.text.trim()
              : null,
          artist: artistController.text.trim().isNotEmpty
              ? artistController.text.trim()
              : null,
          album: albumController.text.trim().isNotEmpty
              ? albumController.text.trim()
              : null,
          albumArtist: albumArtistController.text.trim().isNotEmpty
              ? albumArtistController.text.trim()
              : null,
          genre: genreController.text.trim().isNotEmpty
              ? genreController.text.trim()
              : null,
          year: yearController.text.trim().isNotEmpty
              ? yearController.text.trim()
              : null,
          trackNumber: trackNumberController.text.trim().isNotEmpty
              ? trackNumberController.text.trim()
              : null,
          composer: composerController.text.trim().isNotEmpty
              ? composerController.text.trim()
              : null,
          lyrics: lyricsController.text.trim().isNotEmpty
              ? lyricsController.text.trim()
              : null,
          artworkBytes:
              _newArtworkBytes, // Incluir artwork si se seleccionó uno nuevo
          customMetadata: customMeta.isNotEmpty ? customMeta : null,
        );

        if (metadataWritten) {
          debugPrint('Metadatos escritos exitosamente al archivo');
        } else {
          debugPrint(
            'No se pudieron escribir metadatos al archivo - continuando con actualización en memoria',
          );
        }
      } catch (e) {
        debugPrint('Error escribiendo metadatos al archivo: $e');
        // Continuar con actualización en memoria aunque falle la escritura
      }

      // Notificar al bloc sobre los cambios
      if (mounted) {
        try {
          context.read<DirectoryBloc>().add(
            UpdateMetadataForFile(workingFile.path, updatedMetadata),
          );
        } catch (e) {
          debugPrint('Error notificando al DirectoryBloc: $e');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              metadataWritten
                  ? 'Metadatos actualizados exitosamente (archivo y memoria)'
                  : 'Metadatos actualizados en la aplicación (archivo no modificado)',
            ),
            backgroundColor: metadataWritten ? Colors.green : Colors.orange,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error saving metadata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _renameFile(String newFileName) async {
    try {
      final directory = widget.audioFile.file.parent;
      final originalPath = widget.audioFile.file.path;
      final extension = originalPath.split('.').last;

      // Asegurar que el nuevo nombre no tenga extensión duplicada
      String cleanNewFileName = newFileName;
      if (cleanNewFileName.toLowerCase().endsWith(
        '.$extension'.toLowerCase(),
      )) {
        cleanNewFileName = cleanNewFileName.substring(
          0,
          cleanNewFileName.length - extension.length - 1,
        );
      }

      final newPath = '${directory.path}/$cleanNewFileName.$extension';

      // Verificar que el archivo no exista ya
      if (await File(newPath).exists() && newPath != originalPath) {
        throw Exception('Ya existe un archivo con ese nombre');
      }

      final newFile = await widget.audioFile.file.rename(newPath);
      debugPrint('File renamed from $originalPath to ${newFile.path}');
    } catch (e) {
      debugPrint('Error renaming file: $e');
      throw Exception('No se pudo renombrar el archivo: $e');
    }
  }

  // Métodos helper para obtener valores de metadatos
  String? _getMetadataValue(String key) {
    return widget.audioFile.metadata?.extras?[key]?.toString();
  }

  bool _isSystemMetadata(String key) {
    const systemKeys = {'fileSize', 'path', 'hasMetadata'};
    return systemKeys.contains(key);
  }

  bool _isStandardMetadata(String key) {
    const standardKeys = {
      'year',
      'genre',
      'track',
      'albumArtist',
      'composer',
      'lyrics',
    };
    return standardKeys.contains(key);
  }

  void _addCustomMetadata() {
    final key = _customMetadataKeyController.text.trim();
    final value = _customMetadataValueController.text.trim();

    if (key.isNotEmpty &&
        value.isNotEmpty &&
        !customControllers.containsKey(key)) {
      setState(() {
        customControllers[key] = TextEditingController(text: value);
        _customMetadataKeyController.clear();
        _customMetadataValueController.clear();
      });
    }
  }

  void _removeCustomMetadata(String key) {
    setState(() {
      customControllers[key]?.dispose();
      customControllers.remove(key);
    });
  }

  /// Mostrar información sobre el servicio de metadatos
  void _showMetadataServiceInfo() async {
    final availableMethod = await MetadataWriterService.getAvailableMethod();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 8),
            Text('Información del servicio'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Método disponible: $availableMethod'),
            const SizedBox(height: 16),
            if (availableMethod == 'ffmpeg') ...[
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('FFmpeg disponible'),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Los metadatos se escribirán directamente al archivo.',
              ),
            ] else if (availableMethod == 'ninguno disponible') ...[
              const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Solo memoria'),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Los metadatos solo se actualizarán en la aplicación.',
              ),
              const SizedBox(height: 16),
              const Text('Para escribir metadatos al archivo:'),
              const SizedBox(height: 8),
              if (Platform.isLinux) ...[
                const Text('• Linux: sudo apt install ffmpeg'),
              ] else if (Platform.isWindows) ...[
                const Text('• Windows: Descarga ffmpeg de ffmpeg.org'),
              ] else if (Platform.isMacOS) ...[
                const Text('• macOS: brew install ffmpeg'),
              ],
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(availableMethod),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
