import 'package:flutter/material.dart';
import 'dart:io';

class ShowImage extends StatelessWidget {
  final dynamic image;
  const ShowImage({super.key, this.image});

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (image == null) {
      imageWidget = const Icon(
        Icons.image_not_supported,
        size: 48,
        color: Colors.grey,
      );
    } else if (image is String &&
        (image.startsWith('http://') || image.startsWith('https://'))) {
      imageWidget = Image.network(
        image,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) =>
            const Icon(Icons.broken_image, size: 48),
      );
    } else if (image is String) {
      imageWidget = Image.file(
        File(image),
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) =>
            const Icon(Icons.broken_image, size: 48),
      );
    } else if (image is File) {
      imageWidget = Image.file(
        image as File,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) =>
            const Icon(Icons.broken_image, size: 48),
      );
    } else {
      imageWidget = const Icon(Icons.image, size: 48);
    }

    return InteractiveViewer(
      panEnabled: true,
      minScale: 1,
      maxScale: 4,
      child: Center(child: imageWidget),
    );
  }
}
