import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../../core/utils/angle_tracker.dart';
import '../../../../core/utils/frame_analyzer.dart';
import '../../../../core/utils/image_quality_analyzer.dart';

class LiveCaptureState {
  final List<QualityMessage> messages;
  final List<bool> coverage;
  final double currentAngleDegrees;
  final double brightness;
  final double sharpness;

  const LiveCaptureState({
    this.messages = const [],
    this.coverage = const [],
    this.currentAngleDegrees = 0,
    this.brightness = 0,
    this.sharpness = 0,
  });

  LiveCaptureState copyWith({
    List<QualityMessage>? messages,
    List<bool>? coverage,
    double? currentAngleDegrees,
    double? brightness,
    double? sharpness,
  }) {
    return LiveCaptureState(
      messages: messages ?? this.messages,
      coverage: coverage ?? this.coverage,
      currentAngleDegrees: currentAngleDegrees ?? this.currentAngleDegrees,
      brightness: brightness ?? this.brightness,
      sharpness: sharpness ?? this.sharpness,
    );
  }

  int get coveredCount => coverage.where((b) => b).length;
  int get totalBins => coverage.length;
}

class LiveCaptureController extends StateNotifier<LiveCaptureState> {
  LiveCaptureController() : super(const LiveCaptureState()) {
    state = state.copyWith(coverage: _tracker.coverage);
    _gyroSub = gyroscopeEventStream().listen(_onGyro);
  }

  final FrameAnalyzer _analyzer = FrameAnalyzer();
  final AngleTracker _tracker = AngleTracker(bins: 12);

  StreamSubscription<GyroscopeEvent>? _gyroSub;

  // Limites heurísticos. Ajustáveis conforme calibração do dispositivo.
  static const double _darkThreshold = 60;
  static const double _brightThreshold = 210;
  static const double _blurryThreshold = 60; // variância do Laplaciano
  static const double _reflectiveRatio = 0.15; // 15% de pixels saturados

  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _analyzing = false;

  void _onGyro(GyroscopeEvent e) {
    // Em retrato, o eixo Y é aproximadamente o eixo vertical do mundo,
    // que representa o usuário girando em torno do objeto.
    _tracker.onGyro(yawRate: e.y);
    state = state.copyWith(
      coverage: _tracker.coverage,
      currentAngleDegrees: _tracker.currentAngleDegrees,
    );
  }

  /// Processa um frame da câmera. Throttling para ~5fps.
  void processFrame(CameraImage frame) {
    if (_analyzing) return;
    final now = DateTime.now();
    if (now.difference(_lastFrameAt).inMilliseconds < 200) return;
    _lastFrameAt = now;
    _analyzing = true;
    try {
      final q = _analyzer.analyze(frame);
      final msgs = _buildMessages(q);
      state = state.copyWith(
        messages: msgs,
        brightness: q.brightness,
        sharpness: q.sharpness,
      );
    } finally {
      _analyzing = false;
    }
  }

  List<QualityMessage> _buildMessages(FrameQuality q) {
    final list = <QualityMessage>[];

    if (q.brightness < _darkThreshold) {
      list.add(const QualityMessage(
        'Ambiente muito escuro. Aumente a iluminação.',
        QualityLevel.blocker,
      ));
    } else if (q.brightness > _brightThreshold) {
      list.add(const QualityMessage(
        'Iluminação muito forte. Evite luz direta sobre o perfume.',
        QualityLevel.warning,
      ));
    }

    if (q.saturatedRatio > _reflectiveRatio) {
      list.add(const QualityMessage(
        'Muito reflexo no vidro. Ajuste o ângulo da luz.',
        QualityLevel.warning,
      ));
    }

    // Só avalia nitidez se a cena tem luz mínima (em escuro o Laplaciano cai).
    if (q.brightness >= _darkThreshold && q.sharpness < _blurryThreshold) {
      list.add(const QualityMessage(
        'Imagem tremida. Segure firme e aguarde focar.',
        QualityLevel.warning,
      ));
    }

    // Sugestão de próximo ângulo (quando nenhuma das piores mensagens).
    if (list.every((m) => m.level != QualityLevel.blocker)) {
      final hint = _tracker.nextSuggestion();
      if (hint != null && _tracker.coveredCount > 0) {
        list.add(QualityMessage(hint, QualityLevel.ok));
      }
    }

    if (list.isEmpty) {
      list.add(const QualityMessage(
        'Boa! Pode capturar este ângulo.',
        QualityLevel.ok,
      ));
    }
    return list;
  }

  /// Marca a fatia atual como capturada (chamar quando o usuário tira foto).
  void markCaptured() {
    _tracker.markCurrent();
    state = state.copyWith(coverage: _tracker.coverage);
  }

  void reset() {
    _tracker.reset();
    state = LiveCaptureState(coverage: _tracker.coverage);
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    super.dispose();
  }
}

final liveCaptureControllerProvider =
    StateNotifierProvider.autoDispose<LiveCaptureController, LiveCaptureState>(
  (ref) => LiveCaptureController(),
);
