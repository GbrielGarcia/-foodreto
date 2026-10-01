import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../../data/services/establishment_media_service.dart';
import '../../domain/entities/restaurant.dart';
import '../../domain/repositories/restaurant_repository.dart';
import '../providers/establishment_providers.dart';
import '../providers/restaurant_providers.dart';
import '../widgets/location_picker_page.dart';

/// Edicion de ficha publica por el responsable (solo `approved`).
class EditEstablishmentPage extends ConsumerStatefulWidget {
  const EditEstablishmentPage({super.key, required this.establishmentId});

  final String establishmentId;

  @override
  ConsumerState<EditEstablishmentPage> createState() =>
      _EditEstablishmentPageState();
}

class _EditEstablishmentPageState extends ConsumerState<EditEstablishmentPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _website;
  late final TextEditingController _instagram;
  late final TextEditingController _facebook;
  late final TextEditingController _tiktok;
  late final TextEditingController _videoInput;

  var _ready = false;
  var _saving = false;
  var _uploading = false;
  String? _imageUrl;
  String? _logoUrl;
  var _gallery = <String>[];
  var _videos = <String>[];
  var _categoryIds = <String>{};
  double? _latitude;
  double? _longitude;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _description = TextEditingController();
    _address = TextEditingController();
    _city = TextEditingController();
    _country = TextEditingController();
    _phone = TextEditingController();
    _whatsapp = TextEditingController();
    _website = TextEditingController();
    _instagram = TextEditingController();
    _facebook = TextEditingController();
    _tiktok = TextEditingController();
    _videoInput = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final result = await ref
        .read(restaurantRepositoryProvider)
        .getById(widget.establishmentId);
    if (!mounted) return;
    result.fold(
      onSuccess: (r) {
        if (r == null) {
          setState(() => _error = 'Establecimiento no encontrado');
          return;
        }
        final uid = ref.read(currentUserProvider)?.id;
        if (uid == null || !r.canOwnerManage(uid)) {
          setState(
            () => _error =
                'Solo el responsable puede editar un local aprobado.',
          );
          return;
        }
        _name.text = r.name;
        _description.text = r.description;
        _address.text = r.address;
        _city.text = r.city;
        _country.text = r.country;
        _phone.text = r.phone;
        _whatsapp.text = r.whatsapp;
        _website.text = r.websiteUrl;
        _instagram.text = r.instagramUrl;
        _facebook.text = r.facebookUrl;
        _tiktok.text = r.tiktokUrl;
        _latitude = r.latitude;
        _longitude = r.longitude;
        _imageUrl = r.imageUrl;
        _logoUrl = r.logoUrl;
        _gallery = [...r.galleryUrls];
        _videos = [...r.videoUrls];
        _categoryIds = {...r.categoryIds};
        setState(() => _ready = true);
      },
      onFailure: (f) => setState(() => _error = f.message),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _address.dispose();
    _city.dispose();
    _country.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _website.dispose();
    _instagram.dispose();
    _facebook.dispose();
    _tiktok.dispose();
    _videoInput.dispose();
    super.dispose();
  }

  Future<ImagePickSource?> _askImageSource() async {
    return showModalBottomSheet<ImagePickSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Elegir imagen',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Galeria, camara o cualquier carpeta del telefono.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Galeria de fotos'),
                  subtitle: const Text('Albumes del dispositivo'),
                  onTap: () => Navigator.pop(ctx, ImagePickSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: const Text('Archivos / carpetas'),
                  subtitle: const Text('Descargas, Drive, otras carpetas'),
                  onTap: () => Navigator.pop(ctx, ImagePickSource.files),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Camara'),
                  subtitle: const Text('Tomar una foto nueva'),
                  onTap: () => Navigator.pop(ctx, ImagePickSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<XFile?> _pickFile() async {
    final source = await _askImageSource();
    if (source == null) return null;
    final media = ref.read(establishmentMediaServiceProvider);
    try {
      final file = await media.pickImage(source);
      return file;
    } catch (e) {
      // Si falla el origen elegido, probar galeria y luego archivos.
      try {
        if (source != ImagePickSource.gallery) {
          final fallback = await media.pickFromGallery();
          if (fallback != null) return fallback;
        }
        if (source != ImagePickSource.files) {
          return await media.pickFromFiles();
        }
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo abrir el selector. Prueba Galeria o Archivos. ($e)',
            ),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _pickCover() async {
    final file = await _pickFile();
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url = await ref.read(establishmentMediaServiceProvider).uploadCover(
            establishmentId: widget.establishmentId,
            file: file,
          );
      setState(() => _imageUrl = url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Portada lista. Pulsa Guardar.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo subir la portada: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickLogo() async {
    final file = await _pickFile();
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url = await ref.read(establishmentMediaServiceProvider).uploadLogo(
            establishmentId: widget.establishmentId,
            file: file,
          );
      setState(() => _logoUrl = url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil lista. Pulsa Guardar.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo subir el logo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickGallery() async {
    if (_gallery.length >= Restaurant.maxGalleryImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximo ${Restaurant.maxGalleryImages} fotos en galeria.',
          ),
        ),
      );
      return;
    }
    final file = await _pickFile();
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url =
          await ref.read(establishmentMediaServiceProvider).uploadGalleryImage(
                establishmentId: widget.establishmentId,
                file: file,
              );
      setState(() => _gallery = [..._gallery, url]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo subir la imagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _addVideo() {
    final url = _videoInput.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El enlace debe empezar con http')),
      );
      return;
    }
    if (_videos.length >= Restaurant.maxVideoLinks) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximo ${Restaurant.maxVideoLinks} videos.'),
        ),
      );
      return;
    }
    setState(() {
      _videos = [..._videos, url];
      _videoInput.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserProvider)?.id;
    if (uid == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final lat = _latitude;
    final lng = _longitude;
    final result =
        await ref.read(restaurantRepositoryProvider).updateOwnerFields(
              id: widget.establishmentId,
              ownerUid: uid,
              update: OwnerEstablishmentUpdate(
                name: _name.text,
                description: _description.text,
                address: _address.text,
                city: _city.text,
                country: _country.text,
                imageUrl: _imageUrl,
                logoUrl: _logoUrl,
                categoryIds: _categoryIds.toList(),
                latitude: lat,
                longitude: lng,
                phone: _phone.text,
                whatsapp: _whatsapp.text,
                websiteUrl: _website.text,
                instagramUrl: _instagram.text,
                facebookUrl: _facebook.text,
                tiktokUrl: _tiktok.text,
                galleryUrls: _gallery,
                videoUrls: _videos,
              ),
            );
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold(
      onSuccess: (_) {
        ref.invalidate(restaurantProvider(widget.establishmentId));
        ref.invalidate(myEstablishmentsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil del local actualizado')),
        );
        context.pop();
      },
      onFailure: (f) => setState(() => _error = f.message),
    );
  }

  bool get _busy => _saving || _uploading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider).value ?? const [];

    if (_error != null && !_ready) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar local')),
        body: EmptyStateView(
          emoji: '\u26a0\ufe0f',
          title: 'No se puede editar',
          message: _error!,
          actionLabel: 'Volver',
          onAction: () => context.pop(),
        ),
      );
    }

    if (!_ready) {
      return const Scaffold(body: LoadingStateView());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar local'),
        actions: [
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (_uploading)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: LinearProgressIndicator(),
              ),
            _SectionCard(
              title: 'Foto de perfil',
              subtitle: 'Circular, se ve en Explorar y en la ficha',
              child: _LogoPicker(
                logoUrl: _logoUrl,
                enabled: !_busy,
                onPick: _pickLogo,
                onClear: _logoUrl == null
                    ? null
                    : () => setState(() => _logoUrl = null),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: 'Portada',
              subtitle: 'Imagen ancha del local (galeria, camara o archivos)',
              child: _CoverPicker(
                imageUrl: _imageUrl,
                enabled: !_busy,
                onPick: _pickCover,
                onClear: _imageUrl == null
                    ? null
                    : () => setState(() => _imageUrl = null),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: 'Datos del local',
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _description,
                    decoration: const InputDecoration(
                      labelText: 'Descripcion',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'Direccion',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _city,
                          decoration: const InputDecoration(
                            labelText: 'Ciudad',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Requerido'
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextFormField(
                          controller: _country,
                          decoration: const InputDecoration(
                            labelText: 'Pais',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Req.' : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: 'Ubicacion en mapa',
              subtitle:
                  'Elige el punto en Google Maps o usa tu GPS. Opcional.',
              child: LocationPickerField(
                latitude: _latitude,
                longitude: _longitude,
                onChanged: (point) {
                  setState(() {
                    _latitude = point?.latitude;
                    _longitude = point?.longitude;
                  });
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: 'Contacto',
              child: Column(
                children: [
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefono',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _whatsapp,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp',
                      hintText: '+593...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.chat_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _website,
                    decoration: const InputDecoration(
                      labelText: 'Sitio web',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.language),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _instagram,
                    decoration: const InputDecoration(
                      labelText: 'Instagram URL',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _facebook,
                    decoration: const InputDecoration(
                      labelText: 'Facebook URL',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _tiktok,
                    decoration: const InputDecoration(
                      labelText: 'TikTok URL',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: 'Categorias',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in categories.take(16))
                    FilterChip(
                      label: Text('${c.icon} ${c.name}'),
                      selected: _categoryIds.contains(c.id),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) {
                            _categoryIds.add(c.id);
                          } else {
                            _categoryIds.remove(c.id);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title:
                  'Galeria (${_gallery.length}/${Restaurant.maxGalleryImages})',
              subtitle: 'Fotos adicionales del local',
              trailing: FilledButton.tonalIcon(
                onPressed: _busy ? null : _pickGallery,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Anadir'),
              ),
              child: _gallery.isEmpty
                  ? Text(
                      'Todavia no hay fotos. Usa Anadir para elegir de galeria, camara o carpetas.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : SizedBox(
                      height: 104,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _gallery.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _gallery[i],
                                width: 104,
                                height: 104,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: IconButton.filledTonal(
                                iconSize: 16,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(28, 28),
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () => setState(
                                  () => _gallery = [
                                    for (var j = 0; j < _gallery.length; j++)
                                      if (j != i) _gallery[j],
                                  ],
                                ),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: 'Videos',
              subtitle: 'Solo enlaces (YouTube / TikTok / Vimeo)',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _videoInput,
                          decoration: const InputDecoration(
                            hintText: 'https://...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _addVideo,
                        icon: const Icon(Icons.add_link),
                      ),
                    ],
                  ),
                  for (final v in _videos)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(
                        v,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(
                          () => _videos = [
                            for (final x in _videos)
                              if (x != v) x,
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSpacing.primaryButtonHeight),
              ),
              child: const Text('Guardar cambios'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => context.push(
                AppRoutes.restaurantPath(widget.establishmentId),
              ),
              child: const Text('Ver perfil publico'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({
    required this.logoUrl,
    required this.enabled,
    required this.onPick,
    this.onClear,
  });

  final String? logoUrl;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Center(
          child: InkWell(
            onTap: enabled ? onPick : null,
            customBorder: const CircleBorder(),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage:
                      logoUrl != null ? NetworkImage(logoUrl!) : null,
                  child: logoUrl == null
                      ? Icon(
                          Icons.storefront_outlined,
                          size: 40,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                ),
                Material(
                  color: theme.colorScheme.primary,
                  shape: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Toca para elegir foto circular',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (logoUrl != null && onClear != null)
          TextButton.icon(
            onPressed: enabled ? onClear : null,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Quitar foto'),
          ),
      ],
    );
  }
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.imageUrl,
    required this.enabled,
    required this.onPick,
    this.onClear,
  });

  final String? imageUrl;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onPick : null,
              child: imageUrl == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 40,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Toca para elegir portada',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Galeria ? Archivos ? Camara',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(imageUrl!, fit: BoxFit.cover),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            color: Colors.black54,
                            child: const Text(
                              'Toca para cambiar',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        if (imageUrl != null && onClear != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: enabled ? onClear : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Quitar portada'),
            ),
          ),
        ],
      ],
    );
  }
}
