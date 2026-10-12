import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';

enum ImagePickSource { gallery, camera }

/// Wraps the platform image picker so it can be faked in tests and later
/// extended (e.g. background removal or AI clothing detection).
abstract interface class ImagePickerService {
  bool get supportsCamera;

  /// Returns a temporary file path, or null when the user cancels.
  Future<String?> pickImage(ImagePickSource source);
}

class DeviceImagePickerService implements ImagePickerService {
  DeviceImagePickerService([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  bool get supportsCamera => _picker.supportsImageSource(ImageSource.camera);

  @override
  Future<String?> pickImage(ImagePickSource source) async {
    try {
      // Downscaling and re-encoding here keeps stored photos small.
      final file = await _picker.pickImage(
        source: switch (source) {
          ImagePickSource.gallery => ImageSource.gallery,
          ImagePickSource.camera => ImageSource.camera,
        },
        maxWidth: AppConfig.maxImageDimension,
        maxHeight: AppConfig.maxImageDimension,
        imageQuality: AppConfig.imageQuality,
        requestFullMetadata: false,
      );
      return file?.path;
    } on PlatformException catch (error) {
      throw ImagePickException(
        error.code.contains('camera')
            ? 'Camera access was denied. Enable it in system settings.'
            : 'Could not access your photos. Check app permissions.',
      );
    }
  }
}
