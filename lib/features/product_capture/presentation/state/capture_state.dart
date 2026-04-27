import 'dart:io';

import '../../../../core/utils/image_quality_analyzer.dart';

class CaptureState {
  final List<File> images;
  final List<QualityMessage> qualityMessages;
  final bool uploading;
  final bool selectingFromGallery;
  final double uploadProgress;
  final String? error;

  const CaptureState({
    this.images = const [],
    this.qualityMessages = const [],
    this.uploading = false,
    this.selectingFromGallery = false,
    this.uploadProgress = 0,
    this.error,
  });

  CaptureState copyWith({
    List<File>? images,
    List<QualityMessage>? qualityMessages,
    bool? uploading,
    bool? selectingFromGallery,
    double? uploadProgress,
    String? error,
    bool clearError = false,
  }) {
    return CaptureState(
      images: images ?? this.images,
      qualityMessages: qualityMessages ?? this.qualityMessages,
      uploading: uploading ?? this.uploading,
      selectingFromGallery: selectingFromGallery ?? this.selectingFromGallery,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: clearError ? null : (error ?? this.error),
    );
  }

  int get count => images.length;
  bool get canReview => images.isNotEmpty;
}
