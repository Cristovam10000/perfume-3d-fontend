import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_page.dart';
import '../../features/processing/presentation/pages/processing_status_page.dart';
import '../../features/product_capture/presentation/pages/capture_camera_page.dart';
import '../../features/product_capture/presentation/pages/capture_intro_page.dart';
import '../../features/product_capture/presentation/pages/capture_review_page.dart';
import '../../features/product_capture/presentation/state/capture_controller.dart';
import '../../features/product_viewer/presentation/pages/product_3d_viewer_page.dart';
import '../../features/processing/presentation/state/processing_controller.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (_, __) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.captureIntro,
        name: AppRoutes.captureIntroName,
        builder: (_, __) => const CaptureIntroPage(),
      ),
      GoRoute(
        path: AppRoutes.captureCamera,
        name: AppRoutes.captureCameraName,
        builder: (_, __) => const CaptureCameraPage(),
      ),
      GoRoute(
        path: AppRoutes.captureReview,
        name: AppRoutes.captureReviewName,
        redirect: (context, state) {
          final images = ref.read(captureControllerProvider).images;
          if (images.isEmpty) return AppRoutes.captureCamera;
          return null;
        },
        builder: (_, __) => const CaptureReviewPage(),
      ),
      GoRoute(
        path: AppRoutes.processing,
        name: AppRoutes.processingName,
        builder: (_, __) => const ProcessingStatusPage(),
      ),
      GoRoute(
        path: AppRoutes.viewer,
        name: AppRoutes.viewerName,
        redirect: (context, state) {
          final job = ref.read(processingControllerProvider);
          if (!job.isCompleted || job.modelUrl == null) {
            return AppRoutes.processing;
          }
          return null;
        },
        builder: (_, __) => const Product3DViewerPage(),
      ),
    ],
  );
});
