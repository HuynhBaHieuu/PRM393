import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:all_fits/core/widgets/clothing_image.dart';

/// Draws [widget] off screen at [size] and returns it as a PNG, or null
/// when there is no view to draw for. Used for pictures shown outside the
/// app, such as the home screen widget.
///
/// Photos load asynchronously, so the widget is redrawn as they arrive
/// until it has been quiet for a moment, or [timeout].
Future<Uint8List?> snapshotWidget(
  Widget widget, {
  required Size size,
  required double pixelRatio,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final view = ui.PlatformDispatcher.instance.implicitView;
  if (view == null) return null;

  final boundary = RenderRepaintBoundary();
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
      devicePixelRatio: pixelRatio,
    ),
  );
  final pipeline = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final focus = FocusManager();
  var dirty = false;
  final buildOwner = BuildOwner(
    focusManager: focus,
    // A photo finished loading and its widget wants to rebuild.
    onBuildScheduled: () => dirty = true,
  );
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: NoImageFade(child: widget),
  ).attachToRenderTree(buildOwner);

  void draw() {
    dirty = false;
    buildOwner
      ..buildScope(root)
      ..finalizeTree();
    pipeline
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
  }

  try {
    draw();
    final images = PaintingBinding.instance.imageCache;
    final deadline = DateTime.now().add(timeout);
    // Some photos only start loading after an async lookup (asset
    // variants), so wait for a few quiet checks in a row, not one.
    var quiet = 0;
    while (quiet < 3 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final changed = dirty;
      if (changed) draw();
      quiet = changed || images.pendingImageCount > 0 ? 0 : quiet + 1;
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    // Unmount the tree so its images and listeners are released.
    RenderObjectToWidgetAdapter<RenderBox>(container: boundary)
        .attachToRenderTree(buildOwner, root);
    draw();
    focus.dispose();
  }
}
