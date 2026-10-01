import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/avatar/avatar_config.dart';
import '../../core/avatar/dicebear.dart';

/// `false` en tests de widgets para no depender de la red.
final avatarNetworkEnabledProvider = Provider<bool>((ref) => true);

/// Avatar DiceBear circular. Se dibuja desde la API a partir de estilo +
/// semilla + opciones, sin imágenes almacenadas.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.avatar,
    this.size = 48,
    this.heroTag,
    this.ring = false,
  });

  final AvatarConfig avatar;
  final double size;

  /// Si se indica, anima el avatar entre pantallas.
  final Object? heroTag;

  /// Aro de color de marca alrededor del avatar.
  final bool ring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useNetwork = ref.watch(avatarNetworkEnabledProvider);
    final scheme = Theme.of(context).colorScheme;
    final url = DiceBear.svgUri(avatar).toString();
    final background =
        _parseHex(avatar.backgroundColor) ?? scheme.surfaceContainerHigh;

    Widget image = ClipOval(
      child: ColoredBox(
        color: background,
        child: SizedBox.square(
          dimension: size,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: Tween(begin: 0.85, end: 1.0).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: useNetwork
                ? SvgPicture.network(
                    url,
                    key: ValueKey(url),
                    width: size,
                    height: size,
                    semanticsLabel: 'Avatar',
                    placeholderBuilder: (_) => _Placeholder(size: size),
                    errorBuilder: (_, _, _) => _Placeholder(size: size),
                  )
                : _Placeholder(key: ValueKey(url), size: size),
          ),
        ),
      ),
    );

    if (ring) {
      image = Container(
        padding: EdgeInsets.all(size * 0.04),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.primary, width: size * 0.035),
        ),
        child: image,
      );
    }

    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }
    return image;
  }

  static Color? _parseHex(String? hex) {
    if (hex == null || hex.length != 6) return null;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Text('🙂', style: TextStyle(fontSize: size * 0.45)),
      ),
    );
  }
}
