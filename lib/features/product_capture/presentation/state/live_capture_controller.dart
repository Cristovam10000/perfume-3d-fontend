import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../../core/utils/frame_analyzer.dart';
import '../../../../core/utils/image_quality_analyzer.dart';
import '../../../../core/utils/orb_similarity_tracker.dart';
import '../../../../core/utils/tilt_tracker.dart';

class LiveCaptureState {
  final List<QualityMessage> messages;
  final double brightness;
  final double sharpness;
  final int capturesCount;
  final AngleVerdict? verdict;
  final int matchCount;
  final bool readyToCapture;

  const LiveCaptureState({
    this.messages = const [],
    this.brightness = 0,
    this.sharpness = 0,
    this.capturesCount = 0,
    this.verdict,
    this.matchCount = 0,
    this.readyToCapture = false,
  });

  LiveCaptureState copyWith({
    List<QualityMessage>? messages,
    double? brightness,
    double? sharpness,
    int? capturesCount,
    AngleVerdict? verdict,
    int? matchCount,
    bool? readyToCapture,
  }) {
    return LiveCaptureState(
      messages: messages ?? this.messages,
      brightness: brightness ?? this.brightness,
      sharpness: sharpness ?? this.sharpness,
      capturesCount: capturesCount ?? this.capturesCount,
      verdict: verdict ?? this.verdict,
      matchCount: matchCount ?? this.matchCount,
      readyToCapture: readyToCapture ?? this.readyToCapture,
    );
  }
}

class LiveCaptureController extends StateNotifier<LiveCaptureState> {
  LiveCaptureController() : super(const LiveCaptureState()) {
    _accelSub = accelerometerEventStream().listen(_onAccel);
  }

  final FrameAnalyzer _analyzer = FrameAnalyzer();
  final TiltTracker _tilt = TiltTracker();
  final OrbSimilarityTracker _similarity = OrbSimilarityTracker();

  StreamSubscription<AccelerometerEvent>? _accelSub;

  // Limites heurísticos.
  static const double _darkThreshold = 60;
  static const double _brightThreshold = 210;
  static const double _blurryThreshold = 25;
  static const double _reflectiveRatio = 0.15;
  static const double _tiltTolerance = 20;
  // Blur só vira alerta após N leituras consecutivas abaixo do limiar
  // (evita flicker em frames isolados onde o Laplaciano cai por acaso).
  static const int _blurStreakThreshold = 3;

  // Throttling de trabalho pesado.
  static const Duration _analyzerInterval = Duration(milliseconds: 200);
  static const Duration _orbInterval = Duration(milliseconds: 500);

  DateTime _lastAnalyzerAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastOrbAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _analyzing = false;
  bool _classifyingOrb = false;

  FrameQuality? _lastQuality;
  SimilarityResult? _lastSim;
  int _blurStreak = 0;

  void _onAccel(AccelerometerEvent e) {
    _tilt.onAccel(x: e.x, y: e.y, z: e.z);
  }

  /// Processa um frame ao vivo. Análise leve ~5fps, ORB ~2fps.
  void processFrame(CameraImage frame) {
    final now = DateTime.now();
    bool updated = false;

    if (!_analyzing && now.difference(_lastAnalyzerAt) >= _analyzerInterval) {
      _lastAnalyzerAt = now;
      _analyzing = true;
      try {
        final q = _analyzer.analyze(frame);
        _lastQuality = q;
        if (q.brightness >= _darkThreshold && q.sharpness < _blurryThreshold) {
          _blurStreak++;
        } else {
          _blurStreak = 0;
        }
        updated = true;
      } finally {
        _analyzing = false;
      }
    }

    if (!_classifyingOrb && now.difference(_lastOrbAt) >= _orbInterval) {
      _lastOrbAt = now;
      _classifyingOrb = true;
      try {
        _lastSim = _similarity.classifyFrame(frame);
        updated = true;
      } finally {
        _classifyingOrb = false;
      }
    }

    if (updated) _publishState();
  }

  void _publishState() {
    final q = _lastQuality;
    final sim = _lastSim;
    final msgs = _buildMessages(q, sim);
    state = state.copyWith(
      messages: msgs,
      brightness: q?.brightness ?? 0,
      sharpness: q?.sharpness ?? 0,
      capturesCount: _similarity.capturesCount,
      verdict: sim?.verdict,
      matchCount: sim?.bestMatches ?? 0,
      readyToCapture: _isReady(q, sim),
    );
  }

  bool _isReady(FrameQuality? q, SimilarityResult? sim) {
    if (q == null) return false;
    if (q.brightness < _darkThreshold) return false;
    if (q.sharpness < _blurryThreshold) return false;
    if (!_tilt.isLevel(tolerance: _tiltTolerance)) return false;
    if (sim == null) return true;
    return sim.verdict == AngleVerdict.newAngle ||
        sim.verdict == AngleVerdict.noReference;
  }

  List<QualityMessage> _buildMessages(FrameQuality? q, SimilarityResult? sim) {
    final list = <QualityMessage>[];
    if (q == null) {
      list.add(const QualityMessage(
        'Preparando análise…',
        QualityLevel.ok,
      ));
      return list;
    }

    // Bloqueadores: iluminação insuficiente.
    if (q.brightness < _darkThreshold) {
      list.add(const QualityMessage(
        'Ambiente muito escuro. Aumente a iluminação.',
        QualityLevel.blocker,
      ));
    }

    // Inclinação do celular (acelerômetro).
    final tiltMsg = _tilt.correction(tolerance: _tiltTolerance);
    if (tiltMsg != null) {
      list.add(QualityMessage(tiltMsg, QualityLevel.warning));
    }

    // Avisos de qualidade.
    if (q.brightness > _brightThreshold) {
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
    if (q.brightness >= _darkThreshold &&
        q.sharpness < _blurryThreshold &&
        _blurStreak >= _blurStreakThreshold) {
      list.add(const QualityMessage(
        'Imagem tremida. Segure firme e aguarde focar.',
        QualityLevel.warning,
      ));
    }

    // Orientação principal baseada no ORB — só se não houver blocker.
    if (list.every((m) => m.level != QualityLevel.blocker)) {
      final v = sim?.verdict;
      if (v == null || v == AngleVerdict.noReference) {
        list.add(const QualityMessage(
          'Tire a primeira foto com o perfume bem enquadrado.',
          QualityLevel.ok,
        ));
      } else if (v == AngleVerdict.duplicate) {
        list.add(const QualityMessage(
          'Este ângulo já foi capturado. Gire o perfume para outro lado.',
          QualityLevel.warning,
        ));
      } else if (v == AngleVerdict.partialOverlap) {
        list.add(const QualityMessage(
          'Quase um novo ângulo — gire um pouco mais o perfume.',
          QualityLevel.ok,
        ));
      } else if (v == AngleVerdict.newAngle) {
        list.add(const QualityMessage(
          'Novo ângulo detectado — pode capturar.',
          QualityLevel.ok,
        ));
      }
    }

    if (list.isEmpty) {
      list.add(const QualityMessage(
        'Pronto para capturar.',
        QualityLevel.ok,
      ));
    }
    return list;
  }

  /// Registra uma foto recém-capturada. Roda assíncrono porque o decode
  /// do JPEG + ORB custa 200-500ms.
  Future<void> markCapturedFromFile(String path) async {
    await Future(() => _similarity.registerCaptureFromFile(path));
    _publishState();
  }

  void reset() {
    _similarity.reset();
    _lastSim = null;
    _lastQuality = null;
    state = const LiveCaptureState();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _similarity.dispose();
    super.dispose();
  }
}

final liveCaptureControllerProvider =
    StateNotifierProvider.autoDispose<LiveCaptureController, LiveCaptureState>(
  (ref) => LiveCaptureController(),
);
