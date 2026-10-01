import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/value_objects/invite_code.dart';

/// Pide el código de invitación. Devuelve el código normalizado o `null`.
Future<String?> showJoinCodeDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _JoinCodeDialog(),
  );
}

class _JoinCodeDialog extends StatefulWidget {
  const _JoinCodeDialog();

  @override
  State<_JoinCodeDialog> createState() => _JoinCodeDialogState();
}

class _JoinCodeDialogState extends State<_JoinCodeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(InviteCode.normalize(_code.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unirme a un reto'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(letterSpacing: 6),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(InviteCode.length),
          ],
          decoration: const InputDecoration(hintText: 'AB12CD'),
          validator: (value) => InviteCode.isValid(value ?? '')
              ? null
              : 'Código de ${InviteCode.length} caracteres.',
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Unirme')),
      ],
    );
  }
}
