import 'package:flutter/material.dart';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'fullscreen_image_viewer.dart';

/// Editor completo de metadatos de una canción
class SongMetadataEditor extends StatefulWidget {
  final MediaItem originalMediaItem;
  final File audioFile;
  final Function(MediaItem updatedMediaItem) onSave;
  final Function(String originalPath, MediaItem updatedMediaItem)?
  onMetadataUpdated;

  const SongMetadataEditor({
    super.key,
    required this.originalMediaItem,
    required this.audioFile,
    required this.onSave,
    this.onMetadataUpdated,
  });

  @override
  State<SongMetadataEditor> createState() => _SongMetadataEditorState();
}

class _SongMetadataEditorState extends State<SongMetadataEditor> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _albumController;
  late TextEditingController _genreController;
  late TextEditingController _yearController;
  late TextEditingController _trackNumberController;
  late TextEditingController _fileNameController;

  String? _newArtworkPath;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.originalMediaItem.title,
    );
    _artistController = TextEditingController(
      text: widget.originalMediaItem.artist ?? '',
    );
    _albumController = TextEditingController(
      text: widget.originalMediaItem.album ?? '',
    );
    _genreController = TextEditingController(
      text: widget.originalMediaItem.genre ?? '',
    );
    _yearController = TextEditingController(text: '');
    _trackNumberController = TextEditingController(text: '');

    // Inicializar el nombre del archivo sin la ruta y extensión
    final fileName = widget.audioFile.path.split('/').last;
    final fileNameWithoutExtension = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    _fileNameController = TextEditingController(text: fileNameWithoutExtension);

    // Agregar listeners para detectar cambios
    _titleController.addListener(_onFieldChanged);
    _artistController.addListener(_onFieldChanged);
    _albumController.addListener(_onFieldChanged);
    _genreController.addListener(_onFieldChanged);
    _yearController.addListener(_onFieldChanged);
    _trackNumberController.addListener(_onFieldChanged);
    _fileNameController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _genreController.dispose();
    _yearController.dispose();
    _trackNumberController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _pickNewArtwork() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _newArtworkPath = result.files.single.path!;
          _hasChanges = true;
        });
      }
    } catch (e) {
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

  void _removeArtwork() {
    setState(() {
      _newArtworkPath = '';
      _hasChanges = true;
    });
  }

  void _resetChanges() {
    setState(() {
      _titleController.text = widget.originalMediaItem.title;
      _artistController.text = widget.originalMediaItem.artist ?? '';
      _albumController.text = widget.originalMediaItem.album ?? '';
      _genreController.text = widget.originalMediaItem.genre ?? '';
      _yearController.text = '';
      _trackNumberController.text = '';

      // Resetear nombre del archivo
      final fileName = widget.audioFile.path.split('/').last;
      final fileNameWithoutExtension = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;
      _fileNameController.text = fileNameWithoutExtension;

      _newArtworkPath = null;
      _hasChanges = false;
    });
  }

  Future<bool> _checkAndRequestPermissions() async {
    try {
      // Verificar si tenemos permisos para gestionar almacenamiento externo
      final manageStorageStatus = await Permission.manageExternalStorage.status;
      if (manageStorageStatus.isGranted) {
        return true;
      }

      // Si no tenemos el permiso, verificar permisos básicos
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) {
        return true;
      }

      // Solicitar permisos
      final manageResult = await Permission.manageExternalStorage.request();
      if (manageResult.isGranted) {
        return true;
      }

      final storageResult = await Permission.storage.request();
      return storageResult.isGranted;
    } catch (e) {
      debugPrint('Error verificando permisos: $e');
      return false;
    }
  }

  Future<File?> _attemptFileRename(File file, String newFileName) async {
    try {
      // Primero intentar renombrar directamente
      final renamedFile = await file.rename(newFileName);
      debugPrint(
        'Archivo renombrado exitosamente: ${file.path} -> $newFileName',
      );
      return renamedFile;
    } catch (e) {
      debugPrint('Error en renombrado directo: $e');

      // Si falla, verificar permisos
      final hasPermissions = await _checkAndRequestPermissions();
      if (!hasPermissions) {
        debugPrint('Sin permisos para renombrar archivo');
        return null;
      }

      // Intentar copiar y eliminar como alternativa
      try {
        final newFile = File(newFileName);
        if (await newFile.exists()) {
          debugPrint('El archivo destino ya existe');
          return null;
        }

        await file.copy(newFileName);
        await file.delete();
        debugPrint(
          'Archivo renombrado usando copy+delete: ${file.path} -> $newFileName',
        );
        return File(newFileName);
      } catch (copyError) {
        debugPrint('Error en copy+delete: $copyError');
        return null;
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Crear el MediaItem actualizado
      Uri? newArtUri = widget.originalMediaItem.artUri;

      // Si hay una nueva imagen seleccionada
      if (_newArtworkPath != null && _newArtworkPath!.isNotEmpty) {
        // Copiar la nueva imagen al directorio temporal
        final newImageFile = File(_newArtworkPath!);
        if (await newImageFile.exists()) {
          final tempDir = Directory.systemTemp;
          final fileName =
              '${widget.audioFile.uri.pathSegments.last}_new_cover.jpg';
          final coverFile = File('${tempDir.path}/$fileName');

          await newImageFile.copy(coverFile.path);
          newArtUri = Uri.file(coverFile.path);
        }
      } else if (_newArtworkPath == '') {
        // Remover artwork
        newArtUri = null;
      }

      // Obtener el nuevo nombre del archivo del controlador específico
      String newFileName = widget.audioFile.path;
      final newTitle = _titleController.text.trim();
      final newFileNameFromController = _fileNameController.text.trim();

      // Usar el nombre del archivo del controlador si está especificado
      if (newFileNameFromController.isNotEmpty) {
        final directory = widget.audioFile.parent;
        final extension = widget.audioFile.path.split('.').last;

        // Limpiar el nombre del archivo para caracteres válidos
        final cleanFileName = newFileNameFromController.replaceAll(
          RegExp(r'[<>:"/\\|?*]'),
          '_',
        );
        newFileName = '${directory.path}/$cleanFileName.$extension';

        // Verificar si el archivo con el nuevo nombre ya existe
        int counter = 1;
        String baseNewFileName = newFileName;
        while (File(newFileName).existsSync() &&
            newFileName != widget.audioFile.path) {
          final baseName = baseNewFileName.substring(
            0,
            baseNewFileName.lastIndexOf('.'),
          );
          final ext = baseNewFileName.substring(
            baseNewFileName.lastIndexOf('.'),
          );
          newFileName = '${baseName}_$counter$ext';
          counter++;
        }
      }

      final updatedMediaItem = MediaItem(
        id: newFileName, // Usar el nuevo nombre como ID
        title: newTitle.isEmpty ? 'Sin título' : newTitle,
        artist: _artistController.text.trim().isEmpty
            ? null
            : _artistController.text.trim(),
        album: _albumController.text.trim().isEmpty
            ? null
            : _albumController.text.trim(),
        genre: _genreController.text.trim().isEmpty
            ? null
            : _genreController.text.trim(),
        artUri: newArtUri,
        extras: {
          ...?widget.originalMediaItem.extras,
          'hasMetadata': true,
          'modified': true,
          'year': _yearController.text.trim(),
          'trackNumber': _trackNumberController.text.trim(),
          'originalPath': widget.audioFile.path,
          'newPath': newFileName,
        },
      );

      // Renombrar el archivo si es necesario
      if (newFileName != widget.audioFile.path) {
        final renamedFile = await _attemptFileRename(
          widget.audioFile,
          newFileName,
        );

        if (renamedFile != null) {
          // Renombrado exitoso
          debugPrint(
            'Archivo renombrado exitosamente: ${widget.audioFile.path} -> $newFileName',
          );
        } else {
          // Fallo en el renombrado - usar MediaItem de respaldo
          debugPrint('No se pudo renombrar archivo, guardando solo metadatos');

          final fallbackMediaItem = MediaItem(
            id: widget.audioFile.path,
            title: newTitle.isEmpty ? 'Sin título' : newTitle,
            artist: _artistController.text.trim().isEmpty
                ? null
                : _artistController.text.trim(),
            album: _albumController.text.trim().isEmpty
                ? null
                : _albumController.text.trim(),
            genre: _genreController.text.trim().isEmpty
                ? null
                : _genreController.text.trim(),
            artUri: newArtUri,
            extras: {
              ...?widget.originalMediaItem.extras,
              'hasMetadata': true,
              'modified': true,
              'year': _yearController.text.trim(),
              'trackNumber': _trackNumberController.text.trim(),
              'originalPath': widget.audioFile.path,
              'newPath': widget.audioFile.path,
            },
          );

          widget.onSave(fallbackMediaItem);

          if (widget.onMetadataUpdated != null) {
            debugPrint(
              'SongMetadataEditor: Notificando onMetadataUpdated (fallback) con originalPath=${widget.audioFile.path}',
            );
            widget.onMetadataUpdated!(widget.audioFile.path, fallbackMediaItem);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Metadatos guardados. No se pudo renombrar el archivo: '
                  'verifica los permisos de almacenamiento en la configuración de la app.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 6),
              ),
            );
            Navigator.of(context).pop();
          }
          return;
        }
      }

      widget.onSave(updatedMediaItem);

      // También notificar al explorador de archivos si está disponible
      if (widget.onMetadataUpdated != null) {
        debugPrint(
          'SongMetadataEditor: Notificando onMetadataUpdated con originalPath=${widget.audioFile.path}, newPath=$newFileName',
        );
        widget.onMetadataUpdated!(widget.audioFile.path, updatedMediaItem);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newFileName != widget.audioFile.path
                  ? 'Metadatos guardados y archivo renombrado correctamente'
                  : 'Metadatos guardados correctamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error al guardar metadatos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
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

  Widget _buildArtworkSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Carátula del álbum',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              if (_newArtworkPath != null && _newArtworkPath!.isNotEmpty) {
                showFullscreenImage(context, _newArtworkPath!);
              } else if (widget.originalMediaItem.artUri != null) {
                showFullscreenImage(
                  context,
                  widget.originalMediaItem.artUri!.toFilePath(),
                );
              }
            },
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildArtworkImage(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _pickNewArtwork,
                icon: const Icon(Icons.image),
                label: const Text('Cambiar'),
              ),
              if (_newArtworkPath != null ||
                  widget.originalMediaItem.artUri != null)
                ElevatedButton.icon(
                  onPressed: _removeArtwork,
                  icon: const Icon(Icons.delete),
                  label: const Text('Quitar'),
                  style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkImage() {
    if (_newArtworkPath != null && _newArtworkPath!.isNotEmpty) {
      return Image.file(
        File(_newArtworkPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _buildPlaceholder(),
      );
    } else if (_newArtworkPath == '') {
      return _buildPlaceholder();
    } else if (widget.originalMediaItem.artUri != null) {
      return Image.file(
        File(widget.originalMediaItem.artUri!.toFilePath()),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _buildPlaceholder(),
      );
    } else {
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 60, color: Colors.grey),
            SizedBox(height: 8),
            Text('Sin carátula', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar metadatos'),
        actions: [
          if (_hasChanges)
            IconButton(
              onPressed: _resetChanges,
              icon: const Icon(Icons.refresh),
              tooltip: 'Deshacer cambios',
            ),
          IconButton(
            onPressed: _hasChanges && !_isLoading ? _saveChanges : null,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            tooltip: 'Guardar cambios',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildArtworkSection(),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _titleController,
                    label: 'Título',
                    icon: Icons.music_note,
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _fileNameController,
                    label: 'Nombre del archivo',
                    icon: Icons.insert_drive_file,
                    helperText: 'Nombre del archivo sin extensión.',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () async {
                        await openAppSettings();
                        if (mounted && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Habilita "Administrar todos los archivos" '
                                'para permitir renombrar archivos en almacenamiento externo',
                              ),
                              duration: Duration(seconds: 5),
                            ),
                          );
                        }
                      },
                      tooltip: 'Abrir configuración de permisos',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _artistController,
                    label: 'Artista',
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _albumController,
                    label: 'Álbum',
                    icon: Icons.album,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _genreController,
                    label: 'Género',
                    icon: Icons.category,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _yearController,
                          label: 'Año',
                          icon: Icons.calendar_today,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _trackNumberController,
                          label: 'Pista #',
                          icon: Icons.format_list_numbered,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _hasChanges && !_isLoading ? _saveChanges : null,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    TextInputType? keyboardType,
    String? helperText,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
        helperText: helperText,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }
}

/// Función auxiliar para mostrar el editor de metadatos
void showSongMetadataEditor(
  BuildContext context,
  MediaItem mediaItem,
  File audioFile,
  Function(MediaItem) onSave, {
  Function(String, MediaItem)? onMetadataUpdated,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => SongMetadataEditor(
        originalMediaItem: mediaItem,
        audioFile: audioFile,
        onSave: onSave,
        onMetadataUpdated: onMetadataUpdated,
      ),
    ),
  );
}
