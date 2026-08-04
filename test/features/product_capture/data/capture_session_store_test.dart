import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_3d_mvp/features/product_capture/data/capture_session_store.dart';

void main() {
  late Directory temporaryDirectory;
  late FileCaptureSessionStore store;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'capture-session-store-test-',
    );
    store = FileCaptureSessionStore(
      supportDirectory: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('copia JPEG sem decodificar e restaura o manifesto', () async {
    final source = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}foto-original.JPG',
    );
    final bytes = List<int>.generate(1024, (index) => index % 256);
    await source.writeAsBytes(bytes);

    final imported = await store.importFile(source, 'front');
    final top = await store.importFile(source, 'top');
    final draft = CaptureSessionDraft(
      cardinalPaths: {'front': imported.path},
      topPath: top.path,
      pendingTarget: 'left',
      productId: 42,
    );
    await store.save(draft);
    final restored = await store.load();

    // v4 acrescentou `material`. As versões anteriores continuam carregando —
    // há testes dedicados para v2 (sem `top`) e v3 (sem `material`).
    expect(draft.toJson()['version'], 4);
    expect(imported.path, isNot(source.path));
    expect(imported.path, endsWith('.jpg'));
    expect(await imported.readAsBytes(), bytes);
    expect(restored.cardinalPaths['front'], imported.path);
    expect(restored.topPath, top.path);
    expect(restored.pendingTarget, 'left');
    expect(restored.productId, 42);
  });

  test('manifesto version 2 sem top continua carregando', () async {
    final draftDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}capture_draft',
    );
    await draftDirectory.create(recursive: true);
    final manifest = File(
      '${draftDirectory.path}${Platform.pathSeparator}session.json',
    );
    await manifest.writeAsString(
      jsonEncode({
        'version': 2,
        'cardinals': {'front': 'front.jpg'},
        'extras': ['extra.jpg'],
        'pendingTarget': 'right',
        'productId': 42,
      }),
    );

    final restored = await store.load();

    expect(restored.cardinalPaths, {'front': 'front.jpg'});
    expect(restored.topPath, isNull);
    expect(restored.extraPaths, ['extra.jpg']);
    expect(restored.pendingTarget, 'right');
    expect(restored.productId, 42);
  });

  test('material sobrevive ao round-trip do manifesto', () async {
    await store.save(
      const CaptureSessionDraft(
        cardinalPaths: {'front': 'front.jpg'},
        material: 'opaque',
      ),
    );

    final restored = await store.load();

    expect(restored.material, 'opaque');
  });

  test('manifesto version 3 sem material continua carregando', () async {
    final draftDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}capture_draft',
    );
    await draftDirectory.create(recursive: true);
    final manifest = File(
      '${draftDirectory.path}${Platform.pathSeparator}session.json',
    );
    await manifest.writeAsString(
      jsonEncode({
        'version': 3,
        'cardinals': {'front': 'front.jpg'},
        'top': 'top.jpg',
        'extras': <String>[],
        'pendingTarget': null,
        'productId': 7,
      }),
    );

    final restored = await store.load();

    expect(restored.cardinalPaths, {'front': 'front.jpg'});
    expect(restored.topPath, 'top.jpg');
    expect(restored.productId, 7);
    expect(restored.material, isNull);
  });

  test('clear remove somente o rascunho privado da captura', () async {
    final unrelated = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}nao-remover.txt',
    );
    await unrelated.writeAsString('preservar');
    await store.save(
      const CaptureSessionDraft(pendingTarget: 'front'),
    );

    await store.clear();

    expect(await unrelated.exists(), isTrue);
    expect((await store.load()).pendingTarget, isNull);
  });
}
