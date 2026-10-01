import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/repositories/restaurant_repository.dart';
import '../providers/establishment_providers.dart';
import '../providers/restaurant_providers.dart';
import '../widgets/location_picker_page.dart';

class CreateEstablishmentPage extends ConsumerStatefulWidget {
  const CreateEstablishmentPage({super.key});

  @override
  ConsumerState<CreateEstablishmentPage> createState() =>
      _CreateEstablishmentPageState();
}

class _CreateEstablishmentPageState
    extends ConsumerState<CreateEstablishmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController(text: 'EC');
  final _address = TextEditingController();
  final _description = TextEditingController();
  double? _latitude;
  double? _longitude;
  var _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _country.dispose();
    _address.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserProvider)?.id;
    if (uid == null) return;
    setState(() => _submitting = true);
    final repo = ref.read(restaurantRepositoryProvider);
    final dupes = await repo.findPossibleDuplicates(
      TextNormalizer.normalize(_name.text),
      _city.text,
    );
    final existing = dupes.fold(onSuccess: (v) => v, onFailure: (_) => []);
    if (existing.isNotEmpty && mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Posible duplicado'),
          content: Text(
            'Ya existe "${existing.first.name}" en ${_city.text}. '
            'Enviar solicitud igual?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (go != true) {
        if (mounted) setState(() => _submitting = false);
        return;
      }
    }
    final result = await repo.createRequest(
      CreateEstablishmentRequest(
        name: _name.text,
        city: _city.text,
        country: _country.text,
        creatorUid: uid,
        address: _address.text,
        description: _description.text,
        latitude: _latitude,
        longitude: _longitude,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    result.fold(
      onSuccess: (_) {
        ref.invalidate(myEstablishmentsProvider);
        context.go(AppRoutes.myEstablishments);
      },
      onFailure: (f) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar establecimiento')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'Ciudad'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _country,
                decoration: const InputDecoration(
                  labelText: 'Pais (ISO, ej. EC)',
                ),
                validator: (v) =>
                    v == null || v.trim().length != 2 ? 'Codigo ISO' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Direccion'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Descripcion'),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Ubicacion',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              LocationPickerField(
                latitude: _latitude,
                longitude: _longitude,
                onChanged: (point) {
                  setState(() {
                    _latitude = point?.latitude;
                    _longitude = point?.longitude;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar solicitud'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
