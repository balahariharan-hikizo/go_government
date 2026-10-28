import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_government/utils/responsive_helper.dart';
import '../../utils/app_colors.dart';
import 'package:go_government/bloc/direction/direction_bloc.dart';
import 'package:go_government/bloc/direction/direction_event.dart';
import 'package:go_government/bloc/direction/direction_state.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';
import '../../widget/common_map.dart';
import '../../service/location_service.dart';
import '../../network/ola_maps_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

/// Full-screen in-app turn-by-turn navigation & route viewer powered by Ola Maps polylines.
class DirectionsScreen extends StatefulWidget {
  final String title;
  final String address;
  final LatLng? destinationCoords;
  final LatLng? originCoords; // Manual/picked location as origin
  final bool initialWalkMode;

  const DirectionsScreen({
    super.key,
    required this.title,
    required this.address,
    this.destinationCoords,
    this.originCoords,
    this.initialWalkMode = false,
  });

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen> {
  late final MapController _mapController;
  LatLng? _destinationLatLng;
  bool _isNavigating = false;
  bool _isWalkMode = false;
  bool _hasFittedBounds = false;

  // Active in-app navigation HUD state
  Timer? _navTimer;
  int _remainingSeconds = 360;
  int _remainingDistanceMeters = 1500;
  int _currentStepIndex = 0;
  String _currentInstruction = 'Head along route toward destination';
  IconData _currentManeuverIcon = Icons.arrow_upward;
  String _originAddress = 'Locating origin...';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _destinationLatLng = widget.destinationCoords;
    _isWalkMode = widget.initialWalkMode;

    _resolveOriginAddress();

    if (_destinationLatLng == null) {
      _geocodeDestination();
    } else {
      _fetchDirections();
    }
  }

  Future<void> _resolveOriginAddress() async {
    final eff = _effectiveOrigin;
    if (eff != null) {
      if (LocationService.hasManualLocation &&
          LocationService.manualAddress != null &&
          LocationService.manualAddress!.trim().isNotEmpty) {
        if (mounted) {
          setState(() {
            _originAddress = LocationService.manualAddress!;
          });
        }
        return;
      }
      final addr = await LocationService.getAddressFromCoordinates(eff.latitude, eff.longitude);
      if (mounted && addr.isNotEmpty) {
        setState(() {
          _originAddress = addr;
        });
        return;
      }
    }
    // Live GPS fallback
    final effectiveAddr = await LocationService.getEffectiveAddress();
    if (mounted && effectiveAddr.isNotEmpty) {
      setState(() {
        _originAddress = effectiveAddr;
      });
    }
  }

  Future<void> _geocodeDestination() async {
    final latLng = await LocationService.getCoordinatesFromAddress(widget.address);
    if (latLng != null && mounted) {
      setState(() {
        _destinationLatLng = latLng;
      });
      _fetchDirections();
    }
  }

  LatLng? get _effectiveOrigin =>
      widget.originCoords ??
      (LocationService.hasManualLocation
          ? (LocationService.getManualPosition() != null
              ? LatLng(
                  LocationService.getManualPosition()!.latitude,
                  LocationService.getManualPosition()!.longitude,
                )
              : null)
          : null);

  void _fetchDirections() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final effectiveOrigin = _effectiveOrigin;
      final originLabel = effectiveOrigin != null
          ? (LocationService.manualAddress ?? 'Manual Location')
          : 'Current Location';
      context.read<DirectionBloc>().add(FetchDirections(
            origin: originLabel,
            destination: widget.address,
            travelMode: _isWalkMode ? 'walking' : 'driving',
            originCoords: effectiveOrigin,
            destCoords: _destinationLatLng,
          ));
    });
  }

  void _toggleTravelMode(bool walkMode) {
    if (_isWalkMode == walkMode) return;
    setState(() {
      _isWalkMode = walkMode;
      _hasFittedBounds = false;
    });
    _fetchDirections();
  }

  IconData _getManeuverIcon(String maneuver) {
    final m = maneuver.toLowerCase();
    if (m.contains('left')) return Icons.turn_left_rounded;
    if (m.contains('right')) return Icons.turn_right_rounded;
    if (m.contains('uturn')) return Icons.u_turn_left_rounded;
    if (m.contains('roundabout')) return Icons.roundabout_right_rounded;
    if (m.contains('arrive') || m.contains('destination')) return Icons.location_on_rounded;
    return Icons.arrow_upward_rounded;
  }

  void _startInAppNavigation(OlaRouteResult? route) {
    final steps = route?.steps ?? [];
    final initialSeconds = route?.durationSeconds.round() ?? (_isWalkMode ? 720 : 360);
    final initialMeters = route?.distanceMeters.round() ?? 1500;
    final initialInstruction = steps.isNotEmpty ? steps.first.instruction : 'Head toward ${widget.title}';
    final initialIcon = steps.isNotEmpty ? _getManeuverIcon(steps.first.maneuver) : Icons.arrow_upward_rounded;

    setState(() {
      _isNavigating = true;
      _currentStepIndex = 0;
      _remainingSeconds = initialSeconds > 0 ? initialSeconds : 300;
      _remainingDistanceMeters = initialMeters;
      _currentInstruction = initialInstruction;
      _currentManeuverIcon = initialIcon;
    });

    // Animate map camera onto the user's starting location at high-accuracy zoom
    final startPt = route?.polylinePoints.isNotEmpty == true
        ? route!.polylinePoints.first
        : LocationService.defaultLocation;
    try {
      _mapController.move(startPt, 17.2);
    } catch (_) {}

    _navTimer?.cancel();
    _navTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingSeconds > 20) {
          _remainingSeconds -= 20;
          _remainingDistanceMeters = (_remainingDistanceMeters - 80).clamp(0, 50000);

          if (steps.isNotEmpty) {
            final progress = 1.0 - (_remainingSeconds / (initialSeconds > 0 ? initialSeconds : 300));
            final targetStepIndex = (progress * steps.length).floor().clamp(0, steps.length - 1);
            _currentStepIndex = targetStepIndex;
            _currentInstruction = steps[_currentStepIndex].instruction;
            _currentManeuverIcon = _getManeuverIcon(steps[_currentStepIndex].maneuver);

            // Follow the polyline points on the map as citizen advances
            if (route != null && route.polylinePoints.isNotEmpty) {
              final ptIdx = (progress * route.polylinePoints.length).floor().clamp(0, route.polylinePoints.length - 1);
              try {
                _mapController.move(route.polylinePoints[ptIdx], 17.2);
              } catch (_) {}
            }
          }
        } else {
          timer.cancel();
          _isNavigating = false;
          _showArrivalDialog();
        }
      });
    });
  }

  void _stopNavigation() {
    _navTimer?.cancel();
    setState(() {
      _isNavigating = false;
      _hasFittedBounds = false;
    });
  }

  void _recenterOnUser() async {
    final eff = _effectiveOrigin;
    if (eff != null && mounted) {
      try {
        _mapController.move(eff, 17.0);
        return;
      } catch (_) {}
    }
    final pos = await LocationService.getCurrentPosition(requestPermission: true, forceGps: true);
    if (pos != null && mounted) {
      try {
        _mapController.move(LatLng(pos.latitude, pos.longitude), 17.0);
      } catch (_) {}
    }
  }

  Future<void> _launchGoogleMapsNavigation([OlaRouteResult? route]) async {
    final eff = _effectiveOrigin;
    final destLat = _destinationLatLng?.latitude;
    final destLng = _destinationLatLng?.longitude;
    final destAddress = widget.address.trim().isNotEmpty ? widget.address.trim() : widget.title;

    final launched = await LocationService.launchTurnByTurnNavigation(
      originLat: eff?.latitude,
      originLng: eff?.longitude,
      originAddress: _originAddress,
      destLat: destLat,
      destLng: destLng,
      address: destAddress,
      isWalking: _isWalkMode,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Could not open Google Maps navigation. Please ensure Google Maps or a browser is available.'),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showArrivalDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 28),
            ),
            const SizedBox(width: 10),
            const Text('You have arrived!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text('You have successfully reached ${widget.title}.\n${widget.address}'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Finish Trip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenColor,
      body: CommonBackground(
        child: SafeArea(
          bottom: false,
          child: BlocConsumer<DirectionBloc, DirectionState>(
            listener: (context, state) {
              if (state is DirectionLoaded && !_hasFittedBounds && !_isNavigating) {
                final points = state.routeResult?.polylinePoints;
                if (points != null && points.length >= 2) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    try {
                      final bounds = LatLngBounds.fromPoints(points);
                      _mapController.fitCamera(
                        CameraFit.bounds(
                          bounds: bounds,
                          padding: EdgeInsets.only(
                            top: Responsive.h(100),
                            bottom: Responsive.h(240),
                            left: Responsive.w(40),
                            right: Responsive.w(40),
                          ),
                        ),
                      );
                      _hasFittedBounds = true;
                    } catch (_) {}
                  });
                }
              }
            },
            builder: (context, directionState) {
              final route = directionState is DirectionLoaded ? directionState.routeResult : null;

              return Stack(
                children: [
                  // 1. Full Screen Interactive Map with Ola Maps Styled Polylines
                  Positioned.fill(
                    child: CommonMap(
                      mapController: _mapController,
                      mapState: _isNavigating ? MapState.navigation : MapState.directions,
                      isWalkMode: _isWalkMode,
                      center: _destinationLatLng,
                      userLocationOverride: _effectiveOrigin,
                      polylines: (route != null && route.polylinePoints.isNotEmpty)
                          ? [
                              // Outer glow casing for high visibility over roads
                              Polyline(
                                points: route.polylinePoints,
                                strokeWidth: 7.5,
                                color: const Color(0xFF0D47A1).withValues(alpha: 0.35),
                                strokeCap: StrokeCap.round,
                                strokeJoin: StrokeJoin.round,
                              ),
                              // Core solid Ola Maps road polyline
                              Polyline(
                                points: route.polylinePoints,
                                strokeWidth: 4.8,
                                color: _isWalkMode ? const Color(0xFF00897B) : const Color(0xFF1E88E5),
                                strokeCap: StrokeCap.round,
                                strokeJoin: StrokeJoin.round,
                              ),
                            ]
                          : null,
                      markers: [
                        // Start point marker (User position dot)
                        if (route != null && route.polylinePoints.isNotEmpty)
                          Marker(
                            point: route.polylinePoints.first,
                            width: 28,
                            height: 28,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 4),
                                ],
                              ),
                            ),
                          ),
                        // Destination Pin Marker
                        if (_destinationLatLng != null)
                          Marker(
                            point: _destinationLatLng!,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Color(0xFFD32F2F),
                                size: 40,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 2. Active In-App Navigation HUD Turn Banner (Top)
                  if (_isNavigating)
                    Positioned(
                      top: Responsive.h(14),
                      left: Responsive.w(16),
                      right: Responsive.w(16),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.w(16),
                          vertical: Responsive.h(14),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(Responsive.w(20)),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.white12, width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: Responsive.w(44),
                              height: Responsive.w(44),
                              decoration: const BoxDecoration(
                                color: Color(0xFF00C853),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _currentManeuverIcon,
                                color: Colors.white,
                                size: Responsive.w(24),
                              ),
                            ),
                            SizedBox(width: Responsive.w(14)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _currentInstruction,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: Responsive.sp(14),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: Responsive.h(3)),
                                  Row(
                                    children: [
                                      const Icon(Icons.circle, size: 6, color: Color(0xFF00E676)),
                                      SizedBox(width: Responsive.w(5)),
                                      Text(
                                        '${_remainingSeconds ~/ 60} min (${(_remainingDistanceMeters / 1000).toStringAsFixed(1)} km) remaining',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.75),
                                          fontSize: Responsive.sp(11),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 3. Top Navigation Bar (When NOT navigating)
                  if (!_isNavigating)
                    Positioned(
                      top: Responsive.h(10),
                      left: Responsive.w(16),
                      right: Responsive.w(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back Button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: Responsive.w(44),
                              height: Responsive.w(44),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.outliner, width: 1.2),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                                ],
                              ),
                              child: const Icon(Icons.chevron_left, color: AppColors.black, size: 24),
                            ),
                          ),

                          // Travel Mode Toggle Selector (Walk vs Drive)
                          Container(
                            height: Responsive.h(42),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(Responsive.w(21)),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                              ],
                              border: Border.all(color: AppColors.outliner, width: 1.2),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _toggleTravelMode(false),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
                                    decoration: BoxDecoration(
                                      color: !_isWalkMode ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(Responsive.w(20)),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.directions_car,
                                          color: !_isWalkMode ? Colors.white : AppColors.black,
                                          size: 18,
                                        ),
                                        SizedBox(width: Responsive.w(6)),
                                        Text(
                                          'Drive',
                                          style: TextStyle(
                                            color: !_isWalkMode ? Colors.white : AppColors.black,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _toggleTravelMode(true),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
                                    decoration: BoxDecoration(
                                      color: _isWalkMode ? const Color(0xFF00897B) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(Responsive.w(20)),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.directions_walk,
                                          color: _isWalkMode ? Colors.white : AppColors.black,
                                          size: 18,
                                        ),
                                        SizedBox(width: Responsive.w(6)),
                                        Text(
                                          'Walk',
                                          style: TextStyle(
                                            color: _isWalkMode ? Colors.white : AppColors.black,
                                            fontSize: 12,
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
                        ],
                      ),
                    ),

                  // 4. Floating Recenter / Locate Action Button
                  Positioned(
                    right: Responsive.w(16),
                    bottom: _isNavigating ? Responsive.h(100) : Responsive.h(220),
                    child: FloatingActionButton.small(
                      heroTag: 'directions_recenter_fab',
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.primary,
                      elevation: 4,
                      onPressed: _recenterOnUser,
                      child: const Icon(Icons.my_location, size: 20),
                    ),
                  ),

                  // Loading Spinner Indicator
                  if (directionState is DirectionLoading)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                            ),
                            SizedBox(width: 12),
                            Text('Calculating Ola Maps route...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),

                  // 5. Bottom Navigation Control Panels
                  Positioned(
                    bottom: Responsive.h(20),
                    left: Responsive.w(16),
                    right: Responsive.w(16),
                    child: _isNavigating
                        ? _buildActiveNavigationPanel()
                        : _buildDirectionsPanel(route),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionsPanel(OlaRouteResult? route) {
    final displayDuration = route != null && route.readableDuration.isNotEmpty
        ? LocationService.cleanDurationString(route.readableDuration)
        : (_isWalkMode ? '' : ' ');
    final displayDistance = route != null && route.readableDistance.isNotEmpty
        ? 'Distance: ${route.readableDistance}'
        : (_isWalkMode ? '' : '');

    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
        border: Border.all(color: AppColors.outliner, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with route title & Ola Maps Polyline indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: CustomText.header(
                  widget.title,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 11, color: Color(0xFF2E7D32)),
                    SizedBox(width: 3),
                    Text(
                      'Ola Maps Polyline',
                      style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(10)),

          // From -> To Address Overview Box
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(12),
              vertical: Responsive.h(10),
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(Responsive.w(12)),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Origin ("From")
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.radio_button_checked, size: 15, color: Color(0xFF2E7D32)),
                    SizedBox(width: Responsive.w(8)),
                    Text(
                      'From: ',
                      style: TextStyle(
                        fontSize: Responsive.sp(11),
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _originAddress,
                        style: TextStyle(
                          fontSize: Responsive.sp(12),
                          fontWeight: FontWeight.w600,
                          color: AppColors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(left: Responsive.w(6)),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 2,
                      height: Responsive.h(8),
                      color: Colors.grey.shade300,
                    ),
                  ),
                ),
                // Destination ("To")
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Color(0xFFD32F2F)),
                    SizedBox(width: Responsive.w(8)),
                    Text(
                      'To: ',
                      style: TextStyle(
                        fontSize: Responsive.sp(11),
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.address.isNotEmpty
                            ? widget.address
                            : widget.title,
                        style: TextStyle(
                          fontSize: Responsive.sp(12),
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.h(12)),

          // Trip Duration / Distance & Main Start Google Maps Navigation Button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomText.title(
                      displayDuration,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E7D32),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: Responsive.h(2)),
                    CustomText.subtitle(
                      displayDistance,
                      fontSize: 11,
                      color: AppColors.grayFont,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              SizedBox(width: Responsive.w(12)),

              // Main Start Navigation Button -> Opens straightaway in Google Maps
              GestureDetector(
                onTap: () => _launchGoogleMapsNavigation(route),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(18),
                    vertical: Responsive.h(11),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(Responsive.w(24)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.navigation, color: Colors.white, size: 15),
                      SizedBox(width: Responsive.w(6)),
                      Text(
                        'Start',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: Responsive.sp(13),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(8)),

          // Secondary Action Info Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Opens Google Maps navigation',
                    style: TextStyle(
                      fontSize: Responsive.sp(10),
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _startInAppNavigation(route),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'In-App Preview',
                        style: TextStyle(
                          fontSize: Responsive.sp(10),
                          color: Colors.grey.shade600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.play_circle_outline, size: 12, color: Colors.grey.shade600),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveNavigationPanel() {
    return Row(
      children: [
        // Stop / Exit Navigation Button
        GestureDetector(
          onTap: _stopNavigation,
          child: Container(
            width: Responsive.w(48),
            height: Responsive.w(48),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
              ],
              border: Border.all(color: Colors.red.shade200, width: 1.2),
            ),
            child: const Icon(
              Icons.close,
              color: Colors.red,
              size: 22,
            ),
          ),
        ),
        SizedBox(width: Responsive.w(12)),

        // Active Trip Status Bar
        Expanded(
          child: Container(
            height: Responsive.h(48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Responsive.w(24)),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
              ],
              border: Border.all(color: AppColors.outliner, width: 1.2),
            ),
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.navigation,
                      color: Color(0xFF2E7D32),
                      size: 18,
                    ),
                    SizedBox(width: Responsive.w(8)),
                    const Text(
                      'Live In-App Route',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_remainingSeconds ~/ 60}m left',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
