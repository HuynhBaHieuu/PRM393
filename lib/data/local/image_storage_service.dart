import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/id_generator.dart';

/// Stores clothing photos and resolves stored references to files.
///
/// Models only keep the *reference* returned by [saveImage]. Keeping
/// references relative means paths survive app restarts and reinstalls
/// (where the app container path can change), and a cloud-backed
/// implementation can later return URLs instead.
abstract interface class ImageStorageService {
  /// Copies the image at [sourcePath] into app storage and returns its
  /// reference. Throws [InvalidImageException] or [StorageException].
  Future<String> saveImage(String sourcePath);

  /// Absolute file path for [reference], or null when it can't be resolved.
  String? resolvePath(String reference);

  Future<void> deleteImage(String reference);
}

class LocalImageStorageService implements ImageStorageService {
  LocalImageStorageService({
    IdGenerator idGenerator = const UuidIdGenerator(),
    Future<Directory> Function()? rootDirectory,
  }) : _ids = idGenerator,
       _rootDirectory = rootDirectory ?? getApplicationDocumentsDirectory;

  static const String folder = 'wardrobe_images';
  static const Set<String> supportedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
    'gif',
    'bmp',
  };

  final IdGenerator _ids;
  final Future<Directory> Function() _rootDirectory;
  String? _rootPath;

  bool get isReady => _rootPath != null;

  /// Must complete before images can be saved or resolved.
  Future<void> init() async {
    try {
      final root = await _rootDirectory();
      await Directory('${root.path}/$folder').create(recursive: true);
      _rootPath = root.path;
    } catch (error) {
      developer.log('Image storage unavailable', name: 'images', error: error);
    }
  }

  @override
  Future<String> saveImage(String sourcePath) async {
    final root = _rootPath;
    if (root == null) {
      throw const StorageException('Photo storage is not available.');
    }
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const InvalidImageException('The selected photo is unavailable.');
    }
    final length = await source.length();
    if (length == 0) {
      throw const InvalidImageException('The selected photo is empty.');
    }
    if (length > AppConfig.maxImageBytes) {
      throw const InvalidImageException('This photo is too large to save.');
    }
    final extension = _extensionOf(sourcePath);
    if (!supportedExtensions.contains(extension)) {
      throw const InvalidImageException('This file type isn’t supported.');
    }

    final reference = '$folder/${_ids.next()}.$extension';
    try {
      await source.copy('$root/$reference');
    } on FileSystemException catch (error) {
      developer.log('Failed to copy image', name: 'images', error: error);
      throw const StorageException('The photo could not be saved.');
    }
    return reference;
  }

  @override
  String? resolvePath(String reference) {
    if (_isAbsolute(reference)) return reference;
    final root = _rootPath;
    return root == null ? null : '$root/$reference';
  }

  @override
  Future<void> deleteImage(String reference) async {
    final path = resolvePath(reference);
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error) {
      // An orphaned file is harmless; never block the user on cleanup.
      developer.log('Failed to delete image', name: 'images', error: error);
    }
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1).toLowerCase();
  }

  static bool _isAbsolute(String path) =>
      path.startsWith('/') || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(path);
}
