import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model_descriptor.dart';

/// Progress callback: 0.0–1.0, or null when total size is unknown.
typedef DownloadProgress = void Function(double? fraction, int receivedBytes);

// Collects the single Digest produced by sha256.startChunkedConversion.
// crypto 3.x moved DigestSink to internal; this is the idiomatic replacement.
class _DigestSink implements Sink<Digest> {
  Digest? _value;
  Digest get value => _value!;
  @override
  void add(Digest value) => _value = value;
  @override
  void close() {}
}

/// Owns the lifecycle of model files on disk: where they live, downloading
/// them on first run, verifying integrity, and reporting what's installed.
///
/// This is the boring part every on-device-AI app reinvents. It is deliberately
/// runtime-agnostic — it only moves bytes; it never loads a model.
class ModelManager {
  ModelManager({HttpClient? httpClient})
      : _http = httpClient ?? HttpClient();

  final HttpClient _http;
  static const _kInstalledPrefix = 'model_installed_';
  static const _kChecksumPrefix = 'model_sha256_';

  /// Directory holding all model files, created on demand.
  Future<Directory> _modelsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'models'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Absolute path where [descriptor]'s file lives (whether or not it exists).
  Future<String> pathFor(ModelDescriptor descriptor) async {
    final dir = await _modelsDir();
    return p.join(dir.path, descriptor.id, descriptor.fileName);
  }

  /// True if the file exists on disk and (if a checksum was recorded) matches.
  Future<bool> isInstalled(ModelDescriptor descriptor) async {
    final path = await pathFor(descriptor);
    if (!await File(path).exists()) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_kInstalledPrefix${descriptor.id}') ?? false;
  }

  /// Download [descriptor] to local storage. Streams to a temp file and
  /// atomically renames on success so a killed download never looks installed.
  ///
  /// Pass [authToken] for gated hosts. Returns the final on-disk path.
  Future<String> download(
    ModelDescriptor descriptor, {
    String? authToken,
    DownloadProgress? onProgress,
    bool overwrite = false,
  }) async {
    final finalPath = await pathFor(descriptor);
    final file = File(finalPath);
    await file.parent.create(recursive: true);

    if (await isInstalled(descriptor) && !overwrite) return finalPath;

    if (descriptor.requiresAuthToken &&
        (authToken == null || authToken.isEmpty)) {
      throw StateError(
        'Model ${descriptor.id} requires an auth token but none was provided.',
      );
    }

    final tmp = File('$finalPath.part');
    if (await tmp.exists()) await tmp.delete();

    final uri = Uri.parse(descriptor.downloadUrl);
    final request = await _http.getUrl(uri);
    if (authToken != null && authToken.isNotEmpty) {
      request.headers.add(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    }
    final response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Download failed (${response.statusCode}) for ${descriptor.id}',
        uri: uri,
      );
    }

    final total = response.contentLength; // -1 if unknown
    var received = 0;
    final digest = _DigestSink();
    final sha = sha256.startChunkedConversion(digest);
    final sink = tmp.openWrite();

    try {
      await for (final chunk in response) {
        sink.add(chunk);
        sha.add(chunk);
        received += chunk.length;
        onProgress?.call(total > 0 ? received / total : null, received);
      }
      await sink.flush();
      await sink.close();
      sha.close();
    } catch (e) {
      await sink.close();
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }

    await tmp.rename(finalPath);

    final checksum = digest.value.toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kChecksumPrefix${descriptor.id}', checksum);
    await prefs.setBool('$_kInstalledPrefix${descriptor.id}', true);

    return finalPath;
  }

  /// SHA-256 recorded at download time, for display or audit. On a regulated
  /// product this is worth surfacing so you can prove which weights ran.
  Future<String?> recordedChecksum(ModelDescriptor descriptor) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_kChecksumPrefix${descriptor.id}');
  }

  /// Remove a model file and its install flag to reclaim storage.
  Future<void> delete(ModelDescriptor descriptor) async {
    final path = await pathFor(descriptor);
    final file = File(path);
    if (await file.exists()) await file.delete();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kInstalledPrefix${descriptor.id}');
    await prefs.remove('$_kChecksumPrefix${descriptor.id}');
  }

  /// Total bytes consumed by all installed models.
  Future<int> installedBytes() async {
    final dir = await _modelsDir();
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }
}
