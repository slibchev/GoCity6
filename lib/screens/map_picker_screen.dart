import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/colors.dart';
import '../localization/translations.dart';
import '../models/map_picker_result.dart';
import '../services/backend_reverse_geocode_service.dart';
import '../widgets/language_selector.dart';

enum MapPickerPurpose { pickup, destination }

class MapPickerScreen extends StatefulWidget {
  final MapPickerPurpose purpose;
  final LatLng initialCameraTarget;
  final LatLng? initialSelectedPoint;
  final String? initialAddress;
  final ReverseGeocodeService? reverseGeocodeService;
  final Duration reverseGeocodeDebounce;

  const MapPickerScreen({
    super.key,
    required this.purpose,
    required this.initialCameraTarget,
    this.initialSelectedPoint,
    this.initialAddress,
    this.reverseGeocodeService,
    this.reverseGeocodeDebounce = const Duration(milliseconds: 350),
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen>
    with AppLanguageAwareState<MapPickerScreen> {
  late final ReverseGeocodeService _reverseGeocodeService;
  late LatLng? _selectedPoint = widget.initialSelectedPoint;
  late String? _selectedAddress = widget.initialAddress;
  Timer? _reverseGeocodeTimer;
  int _selectionRevision = 0;
  bool _isResolvingAddress = false;
  bool _isDraggingMarker = false;

  @override
  void initState() {
    super.initState();
    _reverseGeocodeService =
        widget.reverseGeocodeService ?? const BackendReverseGeocodeService();
  }

  String _coordinatesLabel(LatLng point) =>
      '${point.latitude.toStringAsFixed(5)}, '
      '${point.longitude.toStringAsFixed(5)}';

  void _selectPoint(LatLng point) {
    _reverseGeocodeTimer?.cancel();
    final revision = ++_selectionRevision;
    setState(() {
      _selectedPoint = point;
      _isDraggingMarker = false;
      // Immediately replace any previous address with the new point's fallback.
      _selectedAddress = null;
      _isResolvingAddress = true;
    });
    _reverseGeocodeTimer = Timer(widget.reverseGeocodeDebounce, () {
      unawaited(_resolveAddress(point, revision));
    });
  }

  void _startMarkerDrag(LatLng point) {
    _reverseGeocodeTimer?.cancel();
    _selectionRevision++;
    setState(() {
      _selectedPoint = point;
      _selectedAddress = null;
      _isResolvingAddress = false;
      _isDraggingMarker = true;
    });
  }

  void _updateMarkerDuringDrag(LatLng point) {
    if (!mounted) return;
    setState(() {
      _selectedPoint = point;
      _selectedAddress = null;
      _isResolvingAddress = false;
      _isDraggingMarker = true;
    });
  }

  Future<void> _resolveAddress(LatLng point, int revision) async {
    try {
      final address = await _reverseGeocodeService.reverseGeocode(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (!mounted || revision != _selectionRevision) return;
      setState(() {
        _selectedAddress = address;
        _isResolvingAddress = false;
      });
    } catch (_) {
      if (!mounted || revision != _selectionRevision) return;
      setState(() {
        _selectedAddress = null;
        _isResolvingAddress = false;
      });
    }
  }

  void _confirmSelection() {
    final point = _selectedPoint;
    if (point == null) return;

    Navigator.of(context).pop(
      MapPickerResult(
        address: _selectedAddress?.trim().isNotEmpty == true
            ? _selectedAddress!.trim()
            : _coordinatesLabel(point),
        latitude: point.latitude,
        longitude: point.longitude,
      ),
    );
  }

  @override
  void dispose() {
    _selectionRevision++;
    _reverseGeocodeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final point = _selectedPoint;
    final address = point == null
        ? AppTranslations.mapPickerTapToSelect
        : _selectedAddress?.trim().isNotEmpty == true
        ? _selectedAddress!.trim()
        : _coordinatesLabel(point);
    final title = widget.purpose == MapPickerPurpose.pickup
        ? AppTranslations.mapPickerPickupTitle
        : AppTranslations.mapPickerDestinationTitle;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: point ?? widget.initialCameraTarget,
                zoom: point == null ? 13 : 16,
              ),
              onTap: _selectPoint,
              markers: {
                if (point != null)
                  Marker(
                    markerId: const MarkerId('selected-location'),
                    position: point,
                    draggable: true,
                    onDragStart: _startMarkerDrag,
                    onDrag: _updateMarkerDuringDrag,
                    onDragEnd: _selectPoint,
                  ),
              },
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              compassEnabled: true,
              mapToolbarEnabled: false,
            ),
          ),
          SafeArea(
            top: false,
            child: Material(
              color: Colors.white,
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isResolvingAddress && !_isDraggingMarker)
                      const LinearProgressIndicator(minHeight: 2),
                    const SizedBox(height: 8),
                    Text(
                      AppTranslations.mapPickerSelectedAddress,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_isResolvingAddress && !_isDraggingMarker) ...[
                      const SizedBox(height: 4),
                      Text(
                        AppTranslations.mapPickerResolvingAddress,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: point == null ? null : _confirmSelection,
                        icon: const Icon(Icons.check),
                        label: Text(AppTranslations.confirmLocation),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
