import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_3d_mvp/core/constants/app_constants.dart';
import 'package:perfume_3d_mvp/features/product_capture/presentation/pages/capture_views_page.dart';

void main() {
  test('previews usam ResizeImage e mantêm o arquivo original', () {
    final original = File('foto-original-50mp.jpg');

    final cardinal = capturePreviewImageProvider(
      original,
      cacheWidth: AppConstants.cardinalPreviewCacheWidth,
    ) as ResizeImage;
    expect(cardinal.width, AppConstants.cardinalPreviewCacheWidth);
    expect(cardinal.height, isNull);
    expect((cardinal.imageProvider as FileImage).file.path, original.path);

    final extra = capturePreviewImageProvider(
      original,
      cacheWidth: AppConstants.extraPreviewCacheWidth,
    ) as ResizeImage;
    expect(extra.width, AppConstants.extraPreviewCacheWidth);
    expect(extra.height, isNull);
    expect((extra.imageProvider as FileImage).file.path, original.path);
  });
}
