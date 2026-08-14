import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'food_rotation_label_renderer.dart';
import 'label_data.dart';
import 'label_template.dart';
import 'poke_bowl_label_renderer.dart';

/// Physical label canvas, shared by every template. Both currently
/// supported templates are 3 x 2 inches; the design grid is authored at
/// 300 DPI (900 x 600) and scaled to whatever concrete DPI is requested.
class LabelCanvas {
  const LabelCanvas._();

  static const double designWidth = 900;
  static const double designHeight = 600;
}

/// A template's rendering logic: draws a [LabelData] onto a canvas, scaled
/// to fill whatever size is requested. Both the live preview widget and the
/// final print bitmap call [paint]/[renderToGrayscale] on the same
/// instance, so what the user sees is exactly what gets printed.
///
/// Each implementation only ever receives the [LabelData] subtype it was
/// registered for in [LabelTemplateRenderers] — see the `as` cast at the
/// top of each `paint` override.
abstract class LabelTemplateRenderer {
  const LabelTemplateRenderer();

  /// Paints [data] into [canvas], scaled to fill [outputSize].
  void paint(Canvas canvas, Size outputSize, LabelData data);

  /// Renders [data] at the exact printer resolution and returns a
  /// row-major grayscale buffer (one byte per pixel, 0 = black, 255 =
  /// white), ready for `ZplEncoder.buildLabelZpl`. Generated independently
  /// of the on-screen preview widget so the print output is never an
  /// upscaled screenshot.
  Future<Uint8List> renderToGrayscale({
    required LabelData data,
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    paint(
      canvas,
      Size(width.toDouble(), height.toDouble()),
      data,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (byteData == null) {
      throw StateError('Failed to render label bitmap.');
    }

    final rgba = byteData.buffer.asUint8List();
    final gray = Uint8List(width * height);
    for (var i = 0; i < gray.length; i++) {
      final offset = i * 4;
      final r = rgba[offset];
      final g = rgba[offset + 1];
      final b = rgba[offset + 2];
      gray[i] = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
    }
    return gray;
  }
}

/// Looks up the renderer for a [LabelTemplateType]. Adding template 3 means
/// adding one entry here — nothing that already calls
/// `LabelTemplateRenderers.forType(...)` needs to change.
class LabelTemplateRenderers {
  const LabelTemplateRenderers._();

  static const Map<LabelTemplateType, LabelTemplateRenderer> _byType = {
    LabelTemplateType.pokeBowlBurrito: PokeBowlLabelRenderer(),
    LabelTemplateType.foodRotation: FoodRotationLabelRenderer(),
  };

  static LabelTemplateRenderer forType(LabelTemplateType type) => _byType[type]!;

  static LabelTemplateRenderer forData(LabelData data) => forType(data.templateType);
}
