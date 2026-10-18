import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:path_provider/path_provider.dart';

/// Cuts a clothing photo out of its background, so pieces can be laid out
/// freely on an outfit canvas.
abstract interface class BackgroundRemover {
  /// Writes a PNG of the piece on a transparent background, cropped to the
  /// piece, and returns its path; the caller deletes the file when done.
  /// [source] is a file path or an `https` URL. Returns null when no
  /// cut-out can be made; never throws.
  Future<String?> removeBackground(String source);
}

/// For platforms without on-device segmentation (tests, desktop).
class NoBackgroundRemover implements BackgroundRemover {
  const NoBackgroundRemover();

  @override
  Future<String?> removeBackground(String source) async => null;
}

/// Google ML Kit subject segmentation. Android only, runs on the device.
class MlKitBackgroundRemover implements BackgroundRemover {
  final SubjectSegmenter _segmenter = SubjectSegmenter(
    options: SubjectSegmenterOptions(
      enableForegroundBitmap: true,
      enableForegroundConfidenceMask: false,
      enableMultipleSubjects: SubjectResultOptions(
        enableConfidenceMask: false,
        enableSubjectBitmap: false,
      ),
    ),
  );

  @override
  Future<String?> removeBackground(String source) async {
    File? download;
    try {
      if (source.startsWith('https://')) download = await _download(source);
      final input = InputImage.fromFilePath(download?.path ?? source);
      final result = await _segmenter.processImage(input);
      final foreground = result.foregroundBitmap;
      if (foreground == null) return null;
      final png = await cropToContent(foreground);
      if (png == null) return null;
      final file = await _tempFile('png');
      await file.writeAsBytes(png);
      return file.path;
    } catch (error) {
      // The segmentation model may still be downloading; the photo is used
      // until a later attempt succeeds.
      developer.log('Background not removed', name: 'images', error: error);
      return null;
    } finally {
      if (download != null) await _deleteQuietly(download);
    }
  }

  static Future<File> _download(String url) async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(Uri.parse(url))).close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Photo download failed: ${response.statusCode}');
      }
      final file = await _tempFile('jpg');
      await response.pipe(file.openWrite());
      return file;
    } finally {
      client.close();
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // A leftover temp file is harmless.
    }
  }

  static Future<File> _tempFile(String extension) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return File('${dir.path}/cutout_$stamp.$extension');
  }
}

/// Crops a transparent-background PNG to its visible pixels and scales it
/// so neither side exceeds [maxSide]. Returns null when nothing is visible.
Future<Uint8List?> cropToContent(Uint8List png, {int maxSide = 1200}) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  codec.dispose();
  try {
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgba == null) return null;
    // ponytail: scans on the UI isolate (~100 ms for 12 MP); move to an
    // isolate if saving a piece feels slow.
    final bounds = opaqueBounds(
      rgba.buffer.asUint8List(),
      image.width,
      image.height,
    );
    if (bounds == null) return null;
    final scale = math.min(1.0, maxSide / bounds.longestSide);
    final width = math.max(1, (bounds.width * scale).round());
    final height = math.max(1, (bounds.height * scale).round());
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawImageRect(
      image,
      bounds,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final cropped = await recorder.endRecording().toImage(width, height);
    try {
      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      cropped.dispose();
    }
  } finally {
    image.dispose();
  }
}

/// The smallest rectangle holding every pixel at least [minAlpha] opaque in
/// an RGBA buffer, or null when there is none.
ui.Rect? opaqueBounds(
  Uint8List rgba,
  int width,
  int height, {
  int minAlpha = 16,
}) {
  var left = width, top = height, right = -1, bottom = -1;
  for (var y = 0; y < height; y++) {
    final row = y * width * 4;
    for (var x = 0; x < width; x++) {
      if (rgba[row + x * 4 + 3] < minAlpha) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      bottom = y;
    }
  }
  if (right < 0) return null;
  return ui.Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right + 1.0,
    bottom + 1.0,
  );
}
