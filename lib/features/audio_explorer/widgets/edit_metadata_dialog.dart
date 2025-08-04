import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:audiotags/audiotags.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';

import '../bloc/directory_bloc.dart';
import '../bloc/directory_event.dart';
import '../models/audio_file_item.dart';

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
      title: const Row(
        children: [
          Icon(Icons.edit, color: Colors.blue),
          SizedBox(width: 8),
          Text('Edit Song'),
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
        throw Exception('Debe llenar al menos un campo de metadatos');
      }

      // Verificar si necesitamos renombrar el archivo PRIMERO
      final newFileName = fileNameController.text.trim();
      final currentFileName = widget.audioFile.fileName;
      File workingFile = widget.audioFile.file;

      if (newFileName.isNotEmpty && newFileName != currentFileName) {
        await _renameFile(newFileName);
        // Actualizar la referencia del archivo después del renombramiento
        final directory = widget.audioFile.file.parent;
        final extension = widget.audioFile.file.path.split('.').last;

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
        workingFile = File(newPath);
      }

      // Preparar artwork - preservar el existente si no hay uno nuevo
      List<Picture> pictures = [];
      if (_newArtworkBytes != null) {
        pictures.add(
          Picture(
            bytes: _newArtworkBytes!,
            mimeType: MimeType.jpeg,
            pictureType: PictureType.other,
          ),
        );
      } else if (_newArtworkPath != null) {
        final file = File(_newArtworkPath!);
        final bytes = await file.readAsBytes();
        pictures.add(
          Picture(
            bytes: bytes,
            mimeType: MimeType.jpeg,
            pictureType: PictureType.other,
          ),
        );
      } else {
        // Preservar artwork existente si no se ha cambiado
        try {
          final existingMetadata = await MetadataRetriever.fromFile(
            workingFile,
          );
          if (existingMetadata.albumArt?.isNotEmpty == true) {
            pictures.add(
              Picture(
                bytes: existingMetadata.albumArt!,
                mimeType: MimeType.jpeg,
                pictureType: PictureType.other,
              ),
            );
          }
        } catch (e) {
          debugPrint('Error preserving existing artwork: $e');
        }
      }

      // Crear el tag con los nuevos valores, preservando los existentes cuando los campos están vacíos
      final tag = Tag(
        title: titleController.text.trim().isEmpty
            ? (widget.audioFile.title != 'Unknown' &&
                      widget.audioFile.title.isNotEmpty
                  ? widget.audioFile.title
                  : null)
            : titleController.text.trim(),
        trackArtist: artistController.text.trim().isEmpty
            ? (widget.audioFile.artist != 'Unknown Artist' &&
                      widget.audioFile.artist.isNotEmpty
                  ? widget.audioFile.artist
                  : null)
            : artistController.text.trim(),
        album: albumController.text.trim().isEmpty
            ? (widget.audioFile.album != 'Unknown Album' &&
                      widget.audioFile.album.isNotEmpty
                  ? widget.audioFile.album
                  : null)
            : albumController.text.trim(),
        albumArtist: albumArtistController.text.trim().isEmpty
            ? _getMetadataValue('albumArtist')
            : albumArtistController.text.trim(),
        year: _getYearFromExtras(),
        genre: _getGenreFromExtras(),
        trackNumber: _getTrackNumberFromExtras(),
        lyrics: lyricsController.text.trim().isEmpty
            ? _getMetadataValue('lyrics')
            : lyricsController.text.trim(),
        pictures: pictures,
      );

      // Escribir los metadatos al archivo (ahora con el nombre correcto)
      await AudioTags.write(workingFile.path, tag);

      // Actualizar el estado en el bloc
      final Map<String, dynamic> updatedExtras = Map.from(
        widget.audioFile.metadata?.extras ?? {},
      );

      // Agregar metadatos estándar a extras - preservar existentes si están vacíos
      if (yearController.text.trim().isNotEmpty) {
        updatedExtras['year'] = yearController.text.trim();
      } else if (_getMetadataValue('year') != null) {
        updatedExtras['year'] = _getMetadataValue('year')!;
      }

      if (genreController.text.trim().isNotEmpty) {
        updatedExtras['genre'] = genreController.text.trim();
      } else if (_getMetadataValue('genre') != null) {
        updatedExtras['genre'] = _getMetadataValue('genre')!;
      }

      if (trackNumberController.text.trim().isNotEmpty) {
        updatedExtras['track'] = trackNumberController.text.trim();
      } else if (_getMetadataValue('track') != null) {
        updatedExtras['track'] = _getMetadataValue('track')!;
      }

      if (albumArtistController.text.trim().isNotEmpty) {
        updatedExtras['albumArtist'] = albumArtistController.text.trim();
      } else if (_getMetadataValue('albumArtist') != null) {
        updatedExtras['albumArtist'] = _getMetadataValue('albumArtist')!;
      }

      if (composerController.text.trim().isNotEmpty) {
        updatedExtras['composer'] = composerController.text.trim();
      } else if (_getMetadataValue('composer') != null) {
        updatedExtras['composer'] = _getMetadataValue('composer')!;
      }

      if (lyricsController.text.trim().isNotEmpty) {
        updatedExtras['lyrics'] = lyricsController.text.trim();
      } else if (_getMetadataValue('lyrics') != null) {
        updatedExtras['lyrics'] = _getMetadataValue('lyrics')!;
      }

      // Agregar metadatos personalizados
      for (final entry in customControllers.entries) {
        if (entry.value.text.trim().isNotEmpty) {
          updatedExtras[entry.key] = entry.value.text.trim();
        }
      }

      // Agregar metadatos extra existentes
      for (final entry in extraControllers.entries) {
        if (entry.value.text.trim().isNotEmpty) {
          updatedExtras[entry.key] = entry.value.text.trim();
        }
      }

      final updatedMetadata = MediaItem(
        id: workingFile.path, // Usar la ruta actualizada
        title: titleController.text.trim().isEmpty
            ? (widget.audioFile.title != 'Unknown' &&
                      widget.audioFile.title.isNotEmpty
                  ? widget.audioFile.title
                  : (newFileName.isNotEmpty
                        ? newFileName
                        : widget.audioFile.fileName))
            : titleController.text.trim(),
        artist: artistController.text.trim().isEmpty
            ? (widget.audioFile.artist != 'Unknown Artist' &&
                      widget.audioFile.artist.isNotEmpty
                  ? widget.audioFile.artist
                  : 'Unknown Artist')
            : artistController.text.trim(),
        album: albumController.text.trim().isEmpty
            ? (widget.audioFile.album != 'Unknown Album' &&
                      widget.audioFile.album.isNotEmpty
                  ? widget.audioFile.album
                  : 'Unknown Album')
            : albumController.text.trim(),
        duration: widget.audioFile.duration,
        artUri: widget.audioFile.metadata?.artUri,
        extras: updatedExtras,
      );

      // Enviar evento al bloc para actualizar los metadatos
      if (mounted) {
        try {
          // Intentar acceder al DirectoryBloc
          context.read<DirectoryBloc>().add(
            UpdateMetadataForFile(workingFile.path, updatedMetadata),
          );
        } catch (e) {
          // Si no se puede acceder al DirectoryBloc, solo log el error
          debugPrint('DirectoryBloc no encontrado: $e');
        }

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cambios guardados exitosamente'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
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

  // Métodos helper para extraer metadatos extra de los controladores
  int? _getYearFromExtras() {
    if (yearController.text.trim().isNotEmpty) {
      return int.tryParse(yearController.text.trim());
    }
    // Preservar valor existente si el campo está vacío
    final existing = _getMetadataValue('year');
    if (existing != null) {
      return int.tryParse(existing);
    }
    return null;
  }

  String? _getGenreFromExtras() {
    if (genreController.text.trim().isNotEmpty) {
      return genreController.text.trim();
    }
    // Preservar valor existente si el campo está vacío
    return _getMetadataValue('genre');
  }

  int? _getTrackNumberFromExtras() {
    if (trackNumberController.text.trim().isNotEmpty) {
      return int.tryParse(trackNumberController.text.trim());
    }
    // Preservar valor existente si el campo está vacío
    final existing = _getMetadataValue('track');
    if (existing != null) {
      return int.tryParse(existing);
    }
    return null;
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
}
