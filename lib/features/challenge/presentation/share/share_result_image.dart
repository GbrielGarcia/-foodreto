import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'result_share_card.dart';

/// Captura [ChallengeResultShareCard] fuera de pantalla y abre la hoja nativa.
Future<void> shareChallengeResultImage(
  BuildContext context, {
  required ChallengeResultShareCard card,
  required String caption,
  required String subject,
  String fileStem = 'foodreto-resultado',
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final bytes = await captureShareCard(context, card);
  if (bytes == null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('No se pudo generar la imagen.')),
      );
    return;
  }

  final fileName = '$fileStem.png';
  try {
    if (kIsWeb) {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: fileName,
            ),
          ],
          text: caption,
          subject: subject,
        ),
      );
      if (result.status == ShareResultStatus.unavailable) {
        throw StateError('share unavailable');
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png', name: fileName)],
        text: caption,
        subject: subject,
      ),
    );
    if (result.status == ShareResultStatus.unavailable) {
      throw StateError('share unavailable');
    }
  } catch (_) {
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('No se pudo compartir. Int\u00e9ntalo de nuevo.'),
        ),
      );
  }
}

/// Pinta el widget offscreen y lo rasteriza a PNG.
Future<Uint8List?> captureShareCard(
  BuildContext context,
  Widget card, {
  double pixelRatio = 3,
}) async {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return null;

  final boundaryKey = GlobalKey();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -10000,
      top: 0,
      child: Material(
        type: MaterialType.transparency,
        child: RepaintBoundary(
          key: boundaryKey,
          child: card,
        ),
      ),
    ),
  );

  overlay.insert(entry);
  try {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await WidgetsBinding.instance.endOfFrame;
    // Segundo frame: asegura layout definitivo del RepaintBoundary.
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return null;

    var render = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (render == null || render.debugNeedsPaint) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return null;
      render = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
    }
    if (render == null) return null;

    final image = await render.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}
