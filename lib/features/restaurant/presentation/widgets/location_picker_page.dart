import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as osm;

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/services/geo_distance.dart';
import '../providers/restaurant_providers.dart';

/// Abre el picker a pantalla completa. Devuelve null si cancela.
Future<LatLngPoint?> showLocationPicker(
  BuildContext context, {
  LatLngPoint? initial,
}) {
  return Navigator.of(context).push<LatLngPoint>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LocationPickerPage(initial: initial),
    ),
  );
}

/// Mapa para elegir punto: tap + ubicacion actual.
/// Google Maps si hay API key; si no, OSM (mismo flujo UX).
class LocationPickerPage extends ConsumerStatefulWidget {
  const LocationPickerPage({super.key, this.initial});

  final LatLngPoint? initial;

  @override
  ConsumerState<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends ConsumerState<LocationPickerPage> {
  late LatLngPoint _center;
  LatLngPoint? _selected;
  var _locating = false;
  String? _error;
  gmaps.GoogleMapController? _googleController;
  final _osmController = MapController();

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _center = widget.initial ??
        const LatLngPoint(
          ExploreDefaults.defaultLatitude,
          ExploreDefaults.defaultLongitude,
        );
  }

  @override
  void dispose() {
    _googleController?.dispose();
    _osmController.dispose();
    super.dispose();
  }

  Future<void> _moveCamera(LatLngPoint point) async {
    final c = _googleController;
    if (c != null) {
      await c.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          gmaps.LatLng(point.latitude, point.longitude),
          16,
        ),
      );
      return;
    }
    _osmController.move(osm.LatLng(point.latitude, point.longitude), 16);
  }

  Future<void> _zoomBy(double delta) async {
    final c = _googleController;
    if (c != null) {
      final update = delta > 0
          ? gmaps.CameraUpdate.zoomIn()
          : gmaps.CameraUpdate.zoomOut();
      await c.animateCamera(update);
      return;
    }
    final next = (_osmController.camera.zoom + delta).clamp(3.0, 20.0);
    _osmController.move(_osmController.camera.center, next);
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    final snap =
        await ref.read(locationServiceProvider).getCurrentLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (snap == null) {
      setState(() {
        _error =
            'No se pudo obtener tu ubicacion. Revisa el permiso de GPS.';
      });
      return;
    }
    final point = LatLngPoint(snap.latitude, snap.longitude);
    setState(() {
      _selected = point;
      _center = point;
    });
    await _moveCamera(point);
  }

  void _confirm() {
    final point = _selected;
    if (point == null) {
      setState(() => _error = 'Toca el mapa para marcar el local.');
      return;
    }
    Navigator.of(context).pop(point);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final useGoogle = ref.watch(appConfigProvider).usesGoogleMaps;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicacion del local'),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('LISTO'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              useGoogle
                  ? 'Toca el mapa para colocar el pin, o usa tu ubicacion.'
                  : 'Toca el mapa para colocar el pin (OSM). O usa tu ubicacion.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: useGoogle ? _buildGoogleMap() : _buildOsmMap(),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    children: [
                      Material(
                        elevation: 2,
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(10),
                        child: IconButton(
                          tooltip: 'Acercar',
                          onPressed: () => _zoomBy(1),
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Material(
                        elevation: 2,
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(10),
                        child: IconButton(
                          tooltip: 'Alejar',
                          onPressed: () => _zoomBy(-1),
                          icon: const Icon(Icons.remove_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selected != null)
                    Text(
                      'Lat ${_selected!.latitude.toStringAsFixed(5)}     '
                      'Lng ${_selected!.longitude.toStringAsFixed(5)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _locating ? null : _useCurrentLocation,
                    icon: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                    label: Text(
                      _locating ? 'Obteniendo...' : 'Usar mi ubicacion',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    onPressed: _confirm,
                    child: const Text('Confirmar ubicacion'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleMap() {
    final target = gmaps.LatLng(_center.latitude, _center.longitude);
    final markers = <gmaps.Marker>{
      if (_selected != null)
        gmaps.Marker(
          markerId: const gmaps.MarkerId('picked'),
          position: gmaps.LatLng(
            _selected!.latitude,
            _selected!.longitude,
          ),
          draggable: true,
          onDragEnd: (pos) {
            setState(() {
              _selected = LatLngPoint(pos.latitude, pos.longitude);
              _center = _selected!;
            });
          },
        ),
    };

    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(target: target, zoom: 15),
      markers: markers,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
      mapToolbarEnabled: false,
      compassEnabled: true,
      indoorViewEnabled: false,
      trafficEnabled: false,
      buildingsEnabled: false,
      minMaxZoomPreference: const gmaps.MinMaxZoomPreference(3, 21),
      onMapCreated: (c) => _googleController = c,
      onTap: (pos) {
        setState(() {
          _selected = LatLngPoint(pos.latitude, pos.longitude);
          _center = _selected!;
          _error = null;
        });
      },
    );
  }

  Widget _buildOsmMap() {
    return FlutterMap(
      mapController: _osmController,
      options: MapOptions(
        initialCenter: osm.LatLng(_center.latitude, _center.longitude),
        initialZoom: 15,
        minZoom: 3,
        maxZoom: 20,
        onTap: (_, point) {
          setState(() {
            _selected = LatLngPoint(point.latitude, point.longitude);
            _center = _selected!;
            _error = null;
          });
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.tinguardevtechnology.foodreto',
        ),
        if (_selected != null)
          MarkerLayer(
            markers: [
              Marker(
                point: osm.LatLng(
                  _selected!.latitude,
                  _selected!.longitude,
                ),
                width: 40,
                height: 40,
                child: Icon(
                  Icons.location_on,
                  color: Theme.of(context).colorScheme.primary,
                  size: 40,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Campo de formulario: muestra seleccion + abrir mapa / GPS.
class LocationPickerField extends ConsumerWidget {
  const LocationPickerField({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onChanged,
  });

  final double? latitude;
  final double? longitude;
  final ValueChanged<LatLngPoint?> onChanged;

  bool get _hasPoint => latitude != null && longitude != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _hasPoint ? Icons.place_rounded : Icons.add_location_alt_outlined,
                color: scheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _hasPoint
                      ? 'Lat ${latitude!.toStringAsFixed(5)}\n'
                          'Lng ${longitude!.toStringAsFixed(5)}'
                      : 'Sin ubicacion. Elige en el mapa o usa el GPS.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _hasPoint
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (_hasPoint)
                IconButton(
                  tooltip: 'Quitar',
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  final picked = await showLocationPicker(
                    context,
                    initial: _hasPoint
                        ? LatLngPoint(latitude!, longitude!)
                        : null,
                  );
                  if (picked != null) onChanged(picked);
                },
                icon: const Icon(Icons.map_rounded),
                label: const Text('Mapa'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final snap = await ref
                      .read(locationServiceProvider)
                      .getCurrentLocation();
                  if (snap == null) {
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No se pudo obtener la ubicacion. Revisa permisos GPS.',
                          ),
                        ),
                      );
                    return;
                  }
                  onChanged(LatLngPoint(snap.latitude, snap.longitude));
                },
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('GPS'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
