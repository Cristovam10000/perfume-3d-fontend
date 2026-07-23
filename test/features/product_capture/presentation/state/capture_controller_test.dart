import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:perfume_3d_mvp/features/product_capture/data/capture_repository.dart';
import 'package:perfume_3d_mvp/features/product_capture/data/capture_session_store.dart';
import 'package:perfume_3d_mvp/features/product_capture/presentation/state/capture_controller.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'capture-controller-test-',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('seleciona JPEG original sem recompressão nem resize no picker',
      () async {
    final original = await _temporaryImage(temporaryDirectory, '50mp.jpg');
    final picker = _FakeImagePicker()..nextFile = XFile(original.path);
    final store = _MemoryCaptureSessionStore();
    final controller = _controller(picker: picker, store: store);
    await controller.ready;

    await controller.pickFromGalleryForView('front');

    expect(controller.state.cardinals['front']?.path, original.path);
    expect(picker.calls, hasLength(1));
    expect(picker.calls.single.source, ImageSource.gallery);
    expect(picker.calls.single.maxWidth, isNull);
    expect(picker.calls.single.maxHeight, isNull);
    expect(picker.calls.single.imageQuality, isNull);
    expect(picker.calls.single.requestFullMetadata, isFalse);
    expect(store.draft.cardinalPaths['front'], original.path);
  });

  test('um único lock protege cardinais e extras de pickers concorrentes',
      () async {
    final original = await _temporaryImage(temporaryDirectory, 'front.jpg');
    final pending = Completer<XFile?>();
    final picker = _FakeImagePicker()..pendingPick = pending;
    final controller = _controller(
      picker: picker,
      store: _MemoryCaptureSessionStore(),
    );
    await controller.ready;

    final first = controller.captureForView('front');
    await _nextEventLoop();
    final second = controller.pickExtra(ImageSource.gallery);
    await _nextEventLoop();

    expect(controller.state.selectingImage, isTrue);
    expect(picker.calls, hasLength(1));

    pending.complete(XFile(original.path));
    await Future.wait([first, second]);

    expect(controller.state.selectingImage, isFalse);
    expect(controller.state.cardinals['front']?.path, original.path);
    expect(controller.state.extras, isEmpty);
  });

  test('erro ao selecionar extra é exibido e sempre libera o lock', () async {
    final picker = _FakeImagePicker()
      ..pickError = PlatformException(code: 'already_active');
    final controller = _controller(
      picker: picker,
      store: _MemoryCaptureSessionStore(),
    );
    await controller.ready;

    await controller.pickExtra(ImageSource.gallery);

    expect(controller.state.extras, isEmpty);
    expect(controller.state.selectingImage, isFalse);
    expect(controller.state.error, contains('ainda está aberta'));
  });

  test('restaura sessão e associa lost data à vista persistida', () async {
    final front = await _temporaryImage(temporaryDirectory, 'front.jpg');
    final recovered = await _temporaryImage(temporaryDirectory, 'right.jpg');
    final store = _MemoryCaptureSessionStore(
      CaptureSessionDraft(
        cardinalPaths: {'front': front.path},
        pendingTarget: 'right',
      ),
    );
    final picker = _FakeImagePicker()
      ..lostData = LostDataResponse(
        file: XFile(recovered.path),
        type: RetrieveType.image,
      );

    final controller = _controller(
      picker: picker,
      store: store,
      enableLostDataRecovery: true,
    );
    await controller.ready;

    expect(controller.state.cardinals['front']?.path, front.path);
    expect(controller.state.cardinals['right']?.path, recovered.path);
    expect(store.draft.pendingTarget, isNull);
    expect(store.draft.cardinalPaths['right'], recovered.path);
  });

  test('não atribui lost data a uma vista desconhecida', () async {
    final recovered = await _temporaryImage(temporaryDirectory, 'lost.jpg');
    final picker = _FakeImagePicker()
      ..lostData = LostDataResponse(
        file: XFile(recovered.path),
        type: RetrieveType.image,
      );
    final controller = _controller(
      picker: picker,
      store: _MemoryCaptureSessionStore(),
      enableLostDataRecovery: true,
    );

    await controller.ready;

    expect(controller.state.cardinalCount, 0);
    expect(controller.state.error, contains('vista pendente'));
  });

  test('persiste e envia o productId da captura vinculada', () async {
    final repository = _FakeCaptureRepository();
    final store = _MemoryCaptureSessionStore();
    final controller = _controller(
      picker: _FakeImagePicker(),
      store: store,
      repository: repository,
    );
    await controller.ready;
    await controller.setProductId(42);
    for (final view in ['front', 'left', 'back', 'right']) {
      controller.setCardinal(
        view,
        await _temporaryImage(temporaryDirectory, '$view.jpg'),
      );
    }

    final jobId = await controller.submit();

    expect(jobId, 'job-test');
    expect(repository.lastProductId, 42);
    expect(repository.lastViews, ['front', 'left', 'back', 'right']);
  });
}

CaptureController _controller({
  required _FakeImagePicker picker,
  required _MemoryCaptureSessionStore store,
  bool enableLostDataRecovery = false,
  _FakeCaptureRepository? repository,
}) {
  return CaptureController(
    repository: repository ?? _FakeCaptureRepository(),
    picker: picker,
    sessionStore: store,
    enableLostDataRecovery: enableLostDataRecovery,
  );
}

Future<File> _temporaryImage(Directory directory, String name) async {
  final file = File('${directory.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes([0xff, 0xd8, 0xff, 0xd9]);
  return file;
}

Future<void> _nextEventLoop() => Future<void>.delayed(Duration.zero);

class _PickerCall {
  const _PickerCall({
    required this.source,
    required this.maxWidth,
    required this.maxHeight,
    required this.imageQuality,
    required this.requestFullMetadata,
  });

  final ImageSource source;
  final double? maxWidth;
  final double? maxHeight;
  final int? imageQuality;
  final bool requestFullMetadata;
}

class _FakeImagePicker extends ImagePicker {
  XFile? nextFile;
  Object? pickError;
  Completer<XFile?>? pendingPick;
  LostDataResponse lostData = LostDataResponse.empty();
  final List<_PickerCall> calls = [];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) {
    calls.add(
      _PickerCall(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
        requestFullMetadata: requestFullMetadata,
      ),
    );
    final error = pickError;
    if (error != null) return Future<XFile?>.error(error);
    return pendingPick?.future ?? Future<XFile?>.value(nextFile);
  }

  @override
  Future<LostDataResponse> retrieveLostData() async => lostData;
}

class _MemoryCaptureSessionStore implements CaptureSessionStore {
  _MemoryCaptureSessionStore([
    this.draft = const CaptureSessionDraft(),
  ]);

  CaptureSessionDraft draft;

  @override
  Future<void> clear() async {
    draft = const CaptureSessionDraft();
  }

  @override
  Future<File> importFile(File source, String target) async => source;

  @override
  Future<CaptureSessionDraft> load() async => draft;

  @override
  Future<void> save(CaptureSessionDraft value) async {
    draft = value;
  }
}

class _FakeCaptureRepository implements CaptureRepository {
  int? lastProductId;
  List<String>? lastViews;

  @override
  Future<UploadResult> uploadImages(
    List<File> images, {
    List<String>? views,
    int? productId,
    void Function(double progress)? onProgress,
  }) async {
    lastProductId = productId;
    lastViews = views;
    return const UploadResult('job-test');
  }
}
