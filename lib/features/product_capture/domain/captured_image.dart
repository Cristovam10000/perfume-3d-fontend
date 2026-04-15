import 'dart:io';

class CapturedImage {
  final File file;
  final DateTime capturedAt;

  const CapturedImage({required this.file, required this.capturedAt});

  factory CapturedImage.fromFile(File file) =>
      CapturedImage(file: file, capturedAt: DateTime.now());
}
