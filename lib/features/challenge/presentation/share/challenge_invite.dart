import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/router/app_routes.dart';

/// Enlace y texto de invitación (`/join/CODIGO`). Sin Dynamic Links: en web
/// es la URL de la propia app; en móvil apunta al dominio público, que más
/// adelante abrirá la app con App Links / Universal Links.
abstract final class ChallengeInvite {
  static Uri link({required String baseUrl, required String code}) {
    final base = Uri.parse(baseUrl);
    return base.replace(path: AppRoutes.joinPath(code));
  }

  static String message({
    required String title,
    required String emoji,
    required String code,
    required Uri link,
    String? restaurantName,
  }) => [
    '$emoji $title',
    if (restaurantName != null && restaurantName.isNotEmpty)
      '📍 $restaurantName',
    'Código: $code',
    'Únete aquí: $link',
  ].join('\n');

  /// Base de los enlaces: en web, el origen actual (sirve en localhost y en
  /// cualquier dominio de Hosting); fuera de la web, [publicBaseUrl].
  static String baseUrl(String publicBaseUrl) =>
      kIsWeb ? Uri.base.origin : publicBaseUrl;
}

/// Hoja de compartir nativa en móvil. En web se copia al portapapeles:
/// `share_plus` recurre a `mailto:` cuando el navegador no tiene Web Share.
Future<void> shareInvite(
  BuildContext context, {
  required String message,
  required String subject,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!kIsWeb) {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: message, subject: subject),
      );
      if (result.status != ShareResultStatus.unavailable) return;
    } catch (_) {
      // Sin hoja de compartir: se copia al portapapeles.
    }
  }
  await Clipboard.setData(ClipboardData(text: message));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Invitación copiada. Pégala donde quieras compartirla.'),
      ),
    );
}

Future<void> copyInviteCode(BuildContext context, String code) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: code));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('Código $code copiado.')));
}
