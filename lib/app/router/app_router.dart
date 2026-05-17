import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/processing/presentation/pages/processing_status_page.dart';
import '../../features/product_capture/presentation/pages/capture_intro_page.dart';
import '../../features/product_capture/presentation/pages/capture_views_page.dart';
import '../../features/product_capture/presentation/state/capture_controller.dart';
import '../../features/product_viewer/presentation/pages/product_3d_viewer_page.dart';
import '../../features/processing/presentation/state/processing_controller.dart';
import '../../features/sales/domain/sales_models.dart';
import '../../features/sales/presentation/pages/billing_page.dart';
import '../../features/sales/presentation/pages/client_detail_page.dart';
import '../../features/sales/presentation/pages/clients_page.dart';
import '../../features/sales/presentation/pages/home_dashboard_page.dart';
import '../../features/sales/presentation/pages/notifications_page.dart';
import '../../features/sales/presentation/pages/product_3d_page.dart';
import '../../features/sales/presentation/pages/products_page.dart';
import '../../features/sales/presentation/pages/sale_detail_page.dart';
import '../../features/sales/presentation/pages/sale_wizard_page.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (_, __) => const HomeDashboardPage(),
      ),
      GoRoute(
        path: AppRoutes.clients,
        name: AppRoutes.clientsName,
        builder: (_, __) => const ClientsPage(),
      ),
      GoRoute(
        path: AppRoutes.clientDetail,
        name: AppRoutes.clientDetailName,
        builder: (_, state) => ClientDetailPage(
          id: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.saleNew,
        name: AppRoutes.saleNewName,
        builder: (_, __) => const SaleWizardPage(),
      ),
      GoRoute(
        path: AppRoutes.saleDetail,
        name: AppRoutes.saleDetailName,
        builder: (_, state) => SaleDetailPage(
          id: state.pathParameters['id']!,
          draftVenda: state.extra is Venda ? state.extra! as Venda : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.billing,
        name: AppRoutes.billingName,
        builder: (_, __) => const BillingPage(),
      ),
      GoRoute(
        path: AppRoutes.products,
        name: AppRoutes.productsName,
        builder: (_, __) => const ProductsPage(),
      ),
      GoRoute(
        path: AppRoutes.product3d,
        name: AppRoutes.product3dName,
        builder: (_, state) => Product3DPage(
          id: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.captureByProduct,
        name: AppRoutes.captureByProductName,
        builder: (_, __) => const CaptureViewsPage(),
      ),
      GoRoute(
        path: AppRoutes.processingByJob,
        name: AppRoutes.processingByJobName,
        builder: (_, __) => const ProcessingStatusPage(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: AppRoutes.notificationsName,
        builder: (_, __) => const NotificationsPage(),
      ),
      GoRoute(
        path: AppRoutes.captureIntro,
        name: AppRoutes.captureIntroName,
        builder: (_, __) => const CaptureIntroPage(),
      ),
      GoRoute(
        path: AppRoutes.captureCamera,
        name: AppRoutes.captureCameraName,
        builder: (_, __) => const CaptureViewsPage(),
      ),
      GoRoute(
        path: AppRoutes.captureReview,
        name: AppRoutes.captureReviewName,
        redirect: (context, state) {
          // Mantida por compat — fluxo novo concentra captura e revisão na
          // mesma tela. Se não há nada capturado, redireciona pro grid.
          final cardinals =
              ref.read(captureControllerProvider).cardinalCount;
          if (cardinals == 0) return AppRoutes.captureCamera;
          return null;
        },
        builder: (_, __) => const CaptureViewsPage(),
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
