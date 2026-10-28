import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/google_config.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';
import '../../service/location_service.dart';
import '../../network/ola_maps_service.dart';
import '../../hive/hive_service.dart';

/// Screen allowing citizens to pick or search any location where a complaint occurred.
class PickLocationScreen extends StatefulWidget {
  final LatLng? initialLatLng;
  final String? initialAddress;
  final bool? isLiveGps;

  const PickLocationScreen({
    super.key,
    this.initialLatLng,
    this.initialAddress,
    this.isLiveGps,
  });

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  late final MapController _mapController;
  final TextEditingController _searchController = TextEditingController();

  late LatLng _selectedLatLng;
  String _selectedAddress = '';
  bool _isLoadingAddress = false;
  bool _isSearching = false;
  LatLng? _userGpsLocation;

  bool _isUsingLiveGps = false;
  bool _isSubmitting = false;

  // Live Ola Maps Autocomplete & Drag State
  Timer? _searchDebounce;
  Timer? _mapDragDebounce;
  List<OlaPlacePrediction> _predictions = [];
  bool _isLoadingPredictions = false;
  bool _isSelectingPrediction = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    final bool hasManual = LocationService.hasManualLocation;
    _isUsingLiveGps = widget.isLiveGps ?? (!hasManual && widget.initialLatLng == null);

    if (widget.initialLatLng != null) {
      _selectedLatLng = widget.initialLatLng!;
    } else if (hasManual) {
      _selectedLatLng = LocationService.defaultLocation;
    } else if (LocationService.cachedGpsPosition != null) {
      final cached = LocationService.cachedGpsPosition!;
      _selectedLatLng = LatLng(cached.latitude, cached.longitude);
      _userGpsLocation = _selectedLatLng;
    } else {
      _selectedLatLng = LocationService.defaultLocation;
    }

    _selectedAddress = widget.initialAddress ??
        (hasManual
            ? (LocationService.manualAddress ?? 'Selected Location')
            : (LocationService.cachedGpsAddress ?? 'Detecting GPS location...'));

    _searchController.addListener(_onSearchQueryChanged);

    if (widget.initialAddress == null ||
        widget.initialAddress!.isEmpty ||
        _selectedAddress == 'Detecting GPS location...' ||
        _selectedAddress == 'Loading address...') {
      _reverseGeocode(_selectedLatLng);
    }
    _detectUserGps();
  }

  void _onSearchQueryChanged() {
    if (_isSelectingPrediction) return;
    final query = _searchController.text.trim();
    _searchDebounce?.cancel();
    if (query.length < 3) {
      if (_predictions.isNotEmpty || _isLoadingPredictions) {
        setState(() {
          _predictions = [];
          _isLoadingPredictions = false;
        });
      }
      return;
    }

    setState(() => _isLoadingPredictions = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await OlaMapsService.autocompletePlaces(query);
      if (!mounted) return;
      setState(() {
        _predictions = results;
        _isLoadingPredictions = false;
      });
    });
  }

  Future<void> _selectPrediction(OlaPlacePrediction prediction) async {
    FocusScope.of(context).unfocus();
    _isSelectingPrediction = true;
    _isUsingLiveGps = false;
    _searchController.text = prediction.mainText;
    setState(() {
      _predictions = [];
      _isLoadingAddress = true;
    });

    LatLng? coords;
    if (prediction.latitude != null && prediction.longitude != null) {
      coords = LatLng(prediction.latitude!, prediction.longitude!);
    } else {
      coords = await LocationService.getCoordinatesFromAddress(prediction.description);
    }

    if (!mounted) return;
    if (coords != null) {
      setState(() {
        _selectedLatLng = coords!;
      });
      _mapController.move(coords, 16.0);
      await _reverseGeocode(coords);
    } else {
      setState(() => _isLoadingAddress = false);
    }
    _isSelectingPrediction = false;
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      _isUsingLiveGps = false;
      _mapDragDebounce?.cancel();
      _mapDragDebounce = Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() {
          _selectedLatLng = camera.center;
        });
        _reverseGeocode(camera.center);
      });
    }
  }

  Future<void> _detectUserGps() async {
    // If the user explicitly opened manual picker, do NOT query hardware GPS
    if (widget.isLiveGps == false) return;

    final bool hasManual = LocationService.hasManualLocation;

    // 1. Immediately reflect cached GPS if available
    if (LocationService.cachedGpsPosition != null) {
      final cached = LocationService.cachedGpsPosition!;
      final cachedPoint = LatLng(cached.latitude, cached.longitude);
      if (mounted) {
        setState(() {
          _userGpsLocation = cachedPoint;
          if (_isUsingLiveGps || (!hasManual && widget.initialLatLng == null)) {
            _selectedLatLng = cachedPoint;
            _isUsingLiveGps = true;
          }
        });
        if (_isUsingLiveGps || (!hasManual && widget.initialLatLng == null)) {
          try {
            _mapController.move(cachedPoint, 16.0);
          } catch (_) {}
          if (_selectedAddress.isEmpty ||
              _selectedAddress == 'Loading address...' ||
              _selectedAddress == 'Detecting GPS location...') {
            _reverseGeocode(cachedPoint);
          }
        }
      }
    }

    // 2. Query live hardware GPS SILENTLY without popping system dialogs or opening settings
    // If user wants GPS, they can tap the "Use Device Live GPS" button explicitly.
    final Position? pos = await LocationService.getCurrentPosition(
      requestPermission: false,
      forceGps: false,
    );
    if (pos != null && mounted) {
      final userPoint = LatLng(pos.latitude, pos.longitude);
      final bool shouldUpdate =
          _isUsingLiveGps || (!hasManual && widget.initialLatLng == null);
      setState(() {
        _userGpsLocation = userPoint;
        if (shouldUpdate) {
          _selectedLatLng = userPoint;
          _isUsingLiveGps = true;
        }
      });
      if (shouldUpdate) {
        try {
          _mapController.move(userPoint, 16.0);
        } catch (_) {}
        _reverseGeocode(userPoint);
      }
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isLoadingAddress = true);
    final addr = await LocationService.getAddressFromCoordinates(point.latitude, point.longitude);
    if (!mounted) return;
    setState(() {
      _selectedAddress = addr;
      _isLoadingAddress = false;
    });
  }

  void _onMapTapped(LatLng point) {
    _isUsingLiveGps = false;
    setState(() {
      _selectedLatLng = point;
    });
    try {
      _mapController.move(point, _mapController.camera.zoom);
    } catch (_) {}
    _reverseGeocode(point);
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
      _predictions = [];
    });

    final LatLng? coords = await LocationService.getCoordinatesFromAddress(query);
    if (!mounted) return;

    setState(() => _isSearching = false);

    if (coords != null) {
      setState(() {
        _selectedLatLng = coords;
      });
      try {
        _mapController.move(coords, 16.0);
      } catch (_) {}
      _reverseGeocode(coords);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not find "$query". Try entering a landmark or city name.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _recenterOnUserGps() async {
    setState(() {
      _isLoadingAddress = true;
      _isUsingLiveGps = true;
    });

    // 1. Immediate snap if position is already cached or detected
    if (_userGpsLocation != null) {
      _selectedLatLng = _userGpsLocation!;
      try {
        _mapController.move(_userGpsLocation!, 16.0);
      } catch (_) {}
      _reverseGeocode(_userGpsLocation!);
    } else if (LocationService.cachedGpsPosition != null) {
      final cached = LocationService.cachedGpsPosition!;
      final pt = LatLng(cached.latitude, cached.longitude);
      _userGpsLocation = pt;
      _selectedLatLng = pt;
      try {
        _mapController.move(pt, 16.0);
      } catch (_) {}
      _reverseGeocode(pt);
    }

    // 2. Query hardware GPS
    final Position? pos = await LocationService.getCurrentPosition(
      requestPermission: true,
      forceGps: true,
    );
    if (!mounted) return;
    if (pos != null) {
      final userPoint = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _userGpsLocation = userPoint;
        _selectedLatLng = userPoint;
        _isUsingLiveGps = true;
      });
      try {
        _mapController.move(userPoint, 16.0);
      } catch (_) {}
      _reverseGeocode(userPoint);
    } else {
      if (_userGpsLocation == null) {
        setState(() => _isLoadingAddress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not obtain live GPS location. Please check device GPS settings.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _mapDragDebounce?.cancel();
    _searchController.removeListener(_onSearchQueryChanged);
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenColor,
      body: CommonBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // 1. Full Screen Interactive OpenStreetMap
              Positioned.fill(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLatLng,
                    initialZoom: 16.0,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                    onTap: (_, point) => _onMapTapped(point),
                    onPositionChanged: _onPositionChanged,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: GoogleConfig.googleTileUrl,
                      subdomains: GoogleConfig.googleTileSubdomains,
                      maxZoom: 20,
                      userAgentPackageName: 'com.hikizo.gogovernment',
                    ),
                    // Live user GPS location dot if available
                    if (_userGpsLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _userGpsLocation!,
                            width: 24,
                            height: 24,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 4),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    // Selected Complaint Location Pin
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLatLng,
                          width: 48,
                          height: 48,
                          alignment: Alignment.topCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Top Navigation Bar & Search Overlay
              Positioned(
                top: Responsive.h(10),
                left: Responsive.w(16),
                right: Responsive.w(16),
                child: Column(
                  children: [
                    // Header Row with Back Button & Title
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: Responsive.w(44),
                            height: Responsive.w(44),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color: AppColors.outliner,
                                width: 1.2,
                              ),
                            ),
                            child: const Icon(
                              Icons.chevron_left,
                              color: AppColors.black,
                              size: 24,
                            ),
                          ),
                        ),
                        SizedBox(width: Responsive.w(12)),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.w(16),
                              vertical: Responsive.h(10),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(Responsive.w(20)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color: AppColors.outliner,
                                width: 1.2,
                              ),
                            ),
                            child: CustomText.title(
                              'Pick Location',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(10)),

                    // Search Input Bar
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(Responsive.w(24)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                        border: Border.all(
                          color: AppColors.outliner,
                          width: 1.2,
                        ),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(12)),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: AppColors.primary,
                            size: Responsive.w(20),
                          ),
                          SizedBox(width: Responsive.w(8)),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _searchLocation(),
                              decoration: InputDecoration(
                                hintText: 'Search landmark, area or street...',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: Responsive.sp(13),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: Responsive.h(10)),
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              child: const Icon(Icons.close, color: Colors.grey, size: 18),
                            ),
                          SizedBox(width: Responsive.w(4)),
                          GestureDetector(
                            onTap: _searchLocation,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.w(12),
                                vertical: Responsive.h(6),
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(Responsive.w(16)),
                              ),
                              child: _isSearching
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Find',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Autocomplete Progress Indicator
                    if (_isLoadingPredictions)
                      Container(
                        margin: EdgeInsets.only(top: Responsive.h(4)),
                        child: const LinearProgressIndicator(
                          color: AppColors.primary,
                          backgroundColor: Colors.transparent,
                          minHeight: 2,
                        ),
                      ),

                    // Autocomplete Predictions Dropdown Card
                    if (_predictions.isNotEmpty)
                      Container(
                        margin: EdgeInsets.only(top: Responsive.h(6)),
                        constraints: BoxConstraints(maxHeight: Responsive.h(230)),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Responsive.w(16)),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(Responsive.w(16)),
                          clipBehavior: Clip.antiAlias,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(Responsive.w(16)),
                              border: Border.all(color: AppColors.outliner, width: 1.2),
                            ),
                            child: ListView.separated(
                              padding: EdgeInsets.symmetric(vertical: Responsive.h(6)),
                              shrinkWrap: true,
                              itemCount: _predictions.length,
                              separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade200),
                              itemBuilder: (context, index) {
                                final pred = _predictions[index];
                                return ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  leading: const Icon(Icons.place_outlined, color: AppColors.primary, size: 20),
                                  title: Text(
                                    pred.mainText,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  subtitle: pred.secondaryText.isNotEmpty
                                      ? Text(
                                          pred.secondaryText,
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : null,
                                  onTap: () => _selectPrediction(pred),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 3. Floating "Snap to My GPS" Action Button
              Positioned(
                right: Responsive.w(16),
                bottom: Responsive.h(250),
                child: FloatingActionButton.small(
                  heroTag: 'recenter_gps_fab',
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 4,
                  onPressed: _recenterOnUserGps,
                  child: const Icon(Icons.my_location, size: 20),
                ),
              ),

              // 4. Bottom Location Confirmation Card
              Positioned(
                bottom: Responsive.h(20),
                left: Responsive.w(16),
                right: Responsive.w(16),
                child: Container(
                  padding: EdgeInsets.all(Responsive.w(16)),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(Responsive.w(20)),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: AppColors.outliner,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: Responsive.w(10)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: CustomText.title(
                                          _isUsingLiveGps ? 'Live GPS Location' : 'Selected Location',
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _isUsingLiveGps ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: _isUsingLiveGps ? const Color(0xFFA5D6A7) : const Color(0xFFFFCC80),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _isUsingLiveGps ? Icons.my_location : Icons.pin_drop_outlined,
                                                  size: 10,
                                                  color: _isUsingLiveGps ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  _isUsingLiveGps ? 'Live GPS' : 'Custom Pin',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: _isUsingLiveGps ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: Responsive.w(6)),
                                          Text(
                                            '${_selectedLatLng.latitude.toStringAsFixed(4)}, ${_selectedLatLng.longitude.toStringAsFixed(4)}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                SizedBox(height: Responsive.h(4)),
                                _isLoadingAddress
                                    ? Row(
                                        children: [
                                          const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          SizedBox(width: Responsive.w(8)),
                                          const Text(
                                            'Resolving street address...',
                                            style: TextStyle(color: Colors.grey, fontSize: 12),
                                          ),
                                        ],
                                      )
                                    : CustomText.subtitle(
                                        _selectedAddress,
                                        fontSize: 12,
                                        color: const Color(0xFF333333),
                                        maxLines: 2,
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: Responsive.h(14)),
                      const Text(
                        'Tip: Tap anywhere on the map or search to place the complaint pin.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(height: Responsive.h(12)),

                      // Option 1: Explicit "Use Device Live GPS" action
                      GestureDetector(
                        onTap: () async {
                          if (_isSubmitting) return;
                          _isSubmitting = true;
                          final nav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          setState(() => _isLoadingAddress = true);
                          final pos = await LocationService.switchToLiveGps();
                          if (pos != null) {
                            final latLng = LatLng(pos.latitude, pos.longitude);
                            final addr = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
                            nav.pop({
                              'isGps': true,
                              'latLng': latLng,
                              'address': addr,
                            });
                          } else {
                            if (!mounted) return;
                            setState(() {
                              _isLoadingAddress = false;
                              _isSubmitting = false;
                            });
                            messenger.showSnackBar(
                              SnackBar(
                                content: const Text('Could not obtain live GPS. Please enable GPS permissions.'),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: Responsive.h(42),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(Responsive.w(21)),
                            border: Border.all(color: const Color(0xFF2E7D32), width: 1.2),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.my_location, color: Color(0xFF2E7D32), size: 18),
                              SizedBox(width: Responsive.w(8)),
                              Text(
                                'Use Device Live GPS',
                                style: TextStyle(
                                  color: const Color(0xFF2E7D32),
                                  fontSize: Responsive.sp(13),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: Responsive.h(10)),

                      // Option 2: Confirm Pin or GPS Location
                      GestureDetector(
                        onTap: () async {
                          if (_isSubmitting) return;
                          _isSubmitting = true;
                          final nav = Navigator.of(context);
                          if (_isUsingLiveGps) {
                            await LocationService.switchToLiveGps();
                            nav.pop({
                              'isGps': true,
                              'latLng': _selectedLatLng,
                              'address': _selectedAddress,
                            });
                          } else {
                            await HiveService.setManualLocation(
                              latitude: _selectedLatLng.latitude,
                              longitude: _selectedLatLng.longitude,
                              address: _selectedAddress,
                            );
                            nav.pop({
                              'isGps': false,
                              'latLng': _selectedLatLng,
                              'address': _selectedAddress,
                            });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: Responsive.h(46),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(Responsive.w(23)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _isUsingLiveGps ? 'Confirm Live GPS' : 'Confirm Selected Location',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
