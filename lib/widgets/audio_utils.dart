import 'dart:io';

String getFileExtension(String path) {
  int lastDot = path.lastIndexOf('.');
  if (lastDot == -1) return '';
  return path.substring(lastDot);
}

String getFileName(String path) {
  return path.split(Platform.pathSeparator).last;
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String formatDuration(Duration duration) {
  String minutes = duration.inMinutes.toString().padLeft(2, '0');
  String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
