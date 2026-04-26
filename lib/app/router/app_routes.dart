class AppRoutes {
  AppRoutes._();

  static const home = '/';
  static const clients = '/clientes';
  static const clientDetail = '/cliente/:id';
  static const saleNew = '/venda/nova';
  static const saleDetail = '/venda/:id';
  static const billing = '/cobranca';
  static const products = '/produtos';
  static const product3d = '/produto/:id/3d';
  static const captureByProduct = '/captura/:produtoId';
  static const processingByJob = '/processando/:jobId';
  static const notifications = '/notificacoes';

  static const captureIntro = '/capture/intro';
  static const captureCamera = '/capture/camera';
  static const captureReview = '/capture/review';
  static const processing = '/processing';
  static const viewer = '/viewer';

  static const homeName = 'home';
  static const clientsName = 'clients';
  static const clientDetailName = 'client-detail';
  static const saleNewName = 'sale-new';
  static const saleDetailName = 'sale-detail';
  static const billingName = 'billing';
  static const productsName = 'products';
  static const product3dName = 'product-3d';
  static const captureByProductName = 'capture-by-product';
  static const processingByJobName = 'processing-by-job';
  static const notificationsName = 'notifications';

  static const captureIntroName = 'capture-intro';
  static const captureCameraName = 'capture-camera';
  static const captureReviewName = 'capture-review';
  static const processingName = 'processing';
  static const viewerName = 'viewer';
}
