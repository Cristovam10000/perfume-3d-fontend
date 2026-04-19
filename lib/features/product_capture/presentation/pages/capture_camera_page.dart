import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/capture_overlay.dart';
import '../../../../shared/widgets/image_counter.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/quality_banner.dart';
import '../state/capture_controller.dart';
import '../state/live_capture_controller.dart';

class CaptureCameraPage extends ConsumerStatefulWidget {
  const CaptureCameraPage({super.key});

  @override
  ConsumerState<CaptureCameraPage> createState() => _CaptureCameraPageState();
}

class _CaptureCameraPageState extends ConsumerState<CaptureCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;
  String? _cameraError;
  bool _takingPicture = false;
  bool _streaming = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _stopStream();
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initFuture = _initCamera();
      if (mounted) setState(() {});
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'Nenhuma câmera disponível.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _cameraError = null;
      });
      _startStream();
    } catch (e) {
      setState(() => _cameraError = 'Falha ao iniciar câmera: $e');
    }
  }

  void _startStream() {
    final ctrl = _controller;
    if (ctrl == null || _streaming) return;
    _streaming = true;
    ctrl.startImageStream((frame) {
      if (!mounted) return;
      ref.read(liveCaptureControllerProvider.notifier).processFrame(frame);
    });
  }

  Future<void> _stopStream() async {
    final ctrl = _controller;
    if (ctrl == null || !_streaming) return;
    _streaming = false;
    try {
      await ctrl.stopImageStream();
    } catch (_) {}
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _takingPicture) {
      return;
    }
    setState(() => _takingPicture = true);
    try {
      // takePicture exige pausar o stream no plugin `camera` atual.
      await _stopStream();
      final xfile = await controller.takePicture();
      ref
          .read(captureControllerProvider.notifier)
          .addCapturedFile(File(xfile.path));
      await ref
          .read(liveCaptureControllerProvider.notifier)
          .markCapturedFromFile(xfile.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar: $e')),
        );
      }
    } finally {
      _startStream();
      if (mounted) setState(() => _takingPicture = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final capture = ref.watch(captureControllerProvider);
    final live = ref.watch(liveCaptureControllerProvider);
    final controller = ref.read(captureControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: 'Captura guiada',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ImageCounter(count: capture.count),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FutureBuilder<void>(
                  future: _initFuture,
                  builder: (context, snapshot) {
                    if (_cameraError != null) {
                      return _cameraPlaceholder(
                        scheme,
                        icon: Icons.videocam_off_outlined,
                        message: _cameraError!,
                      );
                    }
                    final ctrl = _controller;
                    if (snapshot.connectionState != ConnectionState.done ||
                        ctrl == null ||
                        !ctrl.value.isInitialized) {
                      return Container(
                        color: scheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(),
                      );
                    }
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: ctrl.value.previewSize?.height ?? 1,
                            height: ctrl.value.previewSize?.width ?? 1,
                            child: CameraPreview(ctrl),
                          ),
                        ),
                        const CaptureOverlay(
                          hint:
                              'Centralize o perfume. Gire em torno dele em pequenos ângulos.',
                        ),
                        if (_takingPicture)
                          Container(
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final m in live.messages.take(2)) ...[
                  QualityBanner(message: m),
                  const SizedBox(height: 6),
                ],
                if (capture.error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    capture.error!,
                    style: TextStyle(color: scheme.error, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Galeria',
                  icon: Icons.photo_library_outlined,
                  onPressed: controller.pickFromGallery,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PrimaryButton(
                  label: 'Capturar',
                  icon: Icons.camera_alt_outlined,
                  loading: _takingPicture,
                  onPressed: _controller?.value.isInitialized == true
                      ? _takePicture
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Avançar para revisão',
            icon: Icons.arrow_forward,
            onPressed: capture.canReview
                ? () => context.goNamed(AppRoutes.captureReviewName)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _cameraPlaceholder(
    ColorScheme scheme, {
    required IconData icon,
    required String message,
  }) {
    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: scheme.error),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
