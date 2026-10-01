import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.from});

  /// Ruta a la que volver tras iniciar sesión.
  final String? from;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      title: '¡Hola de nuevo!',
      subtitle: 'Entra y sigue rompiendo récords.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                controller: _password,
                validator: Validators.password,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.lg),
              SubmitButton(
                label: 'ENTRAR',
                isLoading: isLoading,
                onPressed: _submit,
              ),
              const GoogleSignInSection(),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => context.go(
                        Uri(
                          path: AppRoutes.register,
                          queryParameters: widget.from == null
                              ? null
                              : {'from': widget.from},
                        ).toString(),
                      ),
                child: const Text('¿No tienes cuenta? Crear cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
