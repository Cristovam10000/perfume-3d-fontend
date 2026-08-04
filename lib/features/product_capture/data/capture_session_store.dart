import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Estado mínimo necessário para restaurar uma captura interrompida.
class CaptureSessionDraft {
  const CaptureSessionDraft({
    this.cardinalPaths = const {},
    this.topPath,
    this.extraPaths = const [],
    this.pendingTarget,
    this.productId,
    this.material,
  });

  final Map<String, String> cardinalPaths;
  final String? topPath;
  final List<String> extraPaths;
  final String? pendingTarget;
  final int? productId;

  /// `glass`, `opaque` ou null (não informado).
  final String? material;

  Map<String, Object?> toJson() => {
        'version': 4,
        'cardinals': cardinalPaths,
        'top': topPath,
        'extras': extraPaths,
        'pendingTarget': pendingTarget,
        'productId': productId,
        'material': material,
      };

  factory CaptureSessionDraft.fromJson(Map<String, dynamic> json) {
    final rawCardinals = json['cardinals'];
    final rawExtras = json['extras'];
    return CaptureSessionDraft(
      cardinalPaths: rawCardinals is Map
          ? rawCardinals.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
      topPath: json['top'] is String ? json['top'] as String : null,
      extraPaths: rawExtras is List
          ? rawExtras.whereType<String>().toList(growable: false)
          : const [],
      pendingTarget: json['pendingTarget'] is String
          ? json['pendingTarget'] as String
          : null,
      productId:
          json['productId'] is num ? (json['productId'] as num).toInt() : null,
      // Lido com tolerância a ausência: rascunhos gravados nas versões 2 e 3
      // não têm a chave e precisam continuar carregando.
      material: json['material'] is String ? json['material'] as String : null,
    );
  }
}

abstract interface class CaptureSessionStore {
  Future<CaptureSessionDraft> load();

  Future<void> save(CaptureSessionDraft draft);

  /// Copia o arquivo sem decodificar seus pixels para que sobreviva ao fim da
  /// sessão temporária do `image_picker`.
  Future<File> importFile(File source, String target);

  Future<void> clear();
}

class FileCaptureSessionStore implements CaptureSessionStore {
  FileCaptureSessionStore({Future<Directory> Function()? supportDirectory})
      : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _supportDirectory;

  Future<Directory> _draftDirectory() async {
    final support = await _supportDirectory();
    return Directory(
      '${support.path}${Platform.pathSeparator}capture_draft',
    );
  }

  Future<File> _manifestFile() async {
    final directory = await _draftDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}session.json',
    );
  }

  @override
  Future<CaptureSessionDraft> load() async {
    final manifest = await _manifestFile();
    if (!await manifest.exists()) return const CaptureSessionDraft();

    final decoded = jsonDecode(await manifest.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Manifesto de captura inválido.');
    }
    return CaptureSessionDraft.fromJson(decoded);
  }

  @override
  Future<void> save(CaptureSessionDraft draft) async {
    final manifest = await _manifestFile();
    await manifest.parent.create(recursive: true);
    await manifest.writeAsString(jsonEncode(draft.toJson()), flush: true);
  }

  @override
  Future<File> importFile(File source, String target) async {
    if (!await source.exists()) {
      throw FileSystemException(
        'A imagem selecionada não está mais disponível.',
        source.path,
      );
    }

    final directory = await _draftDirectory();
    await directory.create(recursive: true);

    final safeTarget = target.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
    final extension = _safeExtension(source.path);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final destination = File(
      '${directory.path}${Platform.pathSeparator}${safeTarget}_$stamp$extension',
    );
    return source.copy(destination.path);
  }

  @override
  Future<void> clear() async {
    final directory = await _draftDirectory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  static String _safeExtension(String path) {
    final filename = File(path).uri.pathSegments.last;
    final dot = filename.lastIndexOf('.');
    if (dot <= 0 || dot == filename.length - 1) return '.jpg';
    final extension = filename.substring(dot).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(extension)
        ? extension
        : '.jpg';
  }
}
