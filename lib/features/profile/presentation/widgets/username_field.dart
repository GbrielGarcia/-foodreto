import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/username_availability.dart';
import '../../domain/value_objects/username.dart';
import '../providers/profile_providers.dart';

/// `true` solo cuando el username es válido y está libre (o ya es tuyo).
bool isUsernameUsable(AsyncValue<UsernameAvailability> availability) {
  return switch (availability) {
    AsyncData(value: UsernameAvailable() || UsernameOwned()) => true,
    _ => false,
  };
}

/// Campo de @username con validación de formato y disponibilidad en vivo.
class UsernameField extends ConsumerWidget {
  const UsernameField({super.key, required this.controller, this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final text = value.text;
        final formatError = Username.validate(text);
        final availability = formatError == null
            ? ref.watch(usernameAvailabilityProvider(text))
            : null;
        final status = _status(context, formatError, availability);

        return TextFormField(
          controller: controller,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            _LowerCaseFormatter(),
            LengthLimitingTextInputFormatter(Username.maxLength + 5),
          ],
          validator: (v) {
            final error = Username.formValidator(v);
            if (error != null) return error;
            if (availability case AsyncData(value: UsernameTaken())) {
              return 'Ese @username ya está en uso.';
            }
            return null;
          },
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: 'Username',
            prefixText: '@',
            prefixIcon: const Icon(Icons.alternate_email_rounded),
            helperText: status.message,
            helperStyle: TextStyle(color: status.color),
            helperMaxLines: 2,
            suffixIcon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: status.icon,
            ),
          ),
        );
      },
    );
  }

  _Status _status(
    BuildContext context,
    UsernameError? formatError,
    AsyncValue<UsernameAvailability>? availability,
  ) {
    final scheme = Theme.of(context).colorScheme;
    if (formatError != null) {
      return _Status(
        Username.message(formatError),
        scheme.onSurfaceVariant,
        null,
      );
    }
    return switch (availability) {
      AsyncData(value: UsernameAvailable()) => const _Status(
        '¡Disponible!',
        AppColors.mint,
        Icon(
          Icons.check_circle_rounded,
          key: ValueKey('ok'),
          color: AppColors.mint,
        ),
      ),
      AsyncData(value: UsernameOwned()) => _Status(
        'Es tu @username actual.',
        scheme.onSurfaceVariant,
        const Icon(Icons.person_rounded, key: ValueKey('mine')),
      ),
      AsyncData(value: UsernameTaken()) => _Status(
        'Ya está en uso. Prueba con otro.',
        scheme.error,
        Icon(
          Icons.cancel_rounded,
          key: const ValueKey('taken'),
          color: scheme.error,
        ),
      ),
      AsyncError() => _Status(
        'No pudimos comprobarlo. Revisa tu conexión.',
        scheme.error,
        const Icon(Icons.wifi_off_rounded, key: ValueKey('error')),
      ),
      _ => _Status(
        'Comprobando…',
        scheme.onSurfaceVariant,
        const Padding(
          key: ValueKey('loading'),
          padding: EdgeInsets.all(14),
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    };
  }
}

class _Status {
  const _Status(this.message, this.color, this.icon);
  final String message;
  final Color color;
  final Widget? icon;
}

class _LowerCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toLowerCase());
}
