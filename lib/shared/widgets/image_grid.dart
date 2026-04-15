import 'dart:io';

import 'package:flutter/material.dart';

class CapturedImageGrid extends StatelessWidget {
  final List<File> images;
  final void Function(int index)? onRemove;

  const CapturedImageGrid({
    super.key,
    required this.images,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nenhuma imagem capturada ainda.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final file = images[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(file, fit: BoxFit.cover),
            ),
            if (onRemove != null)
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onRemove!(index),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
