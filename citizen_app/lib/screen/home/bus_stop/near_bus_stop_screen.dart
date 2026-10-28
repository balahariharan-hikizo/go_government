import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/responsive_helper.dart';
import '../../../widget/common_background.dart';
import '../../../widget/custom_text.dart';
import '../../../widget/common_map.dart';
import '../../../bloc/bus_stop/bus_stop_bloc.dart';
import '../../../bloc/bus_stop/bus_stop_event.dart';
import '../../../bloc/bus_stop/bus_stop_state.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../service/location_service.dart';
import '../../../network/ola_maps_service.dart';
import '../../../constants/route_constants.dart';
import '../../../hive/hive_service.dart';

enum BusStopFlowState { list, directions, navigation }

class NearBusStopScreen extends StatefulWidget {
  const NearBusStopScreen({super.key});

  @override
  State<NearBusStopScreen> createState() => _NearBusStopScreenState();
}

class _NearBusStopScreenState extends State<NearBusStopScreen> {
  late List<Map<String, dynamic>> _busStops;
  LatLng? _userPos;
  String _locationLabel = 'Your Location';
  bool _isManualLocation = false;
  bool _isNavigating = false;

  // Real-time ETA cache for selected items
  final Map<int, String> _olaBikeDurationCache = {};
  final Map<int, String> _olaWalkDurationCache = {};
  int? _fetchingEtaForIndex;

  @override
  void initState() {
    super.initState();
    // Check if there's already a saved manual location
    if (LocationService.hasManualLocation) {
      final manualPos = LocationService.getManualPosition();
      final manualAddr = LocationService.manualAddress;
      if (manualPos != null) {
        _userPos = LatLng(manualPos.latitude, manualPos.longitude);
        _isManualLocation = true;
        _locationLabel = manualAddr ?? 'Manual Location';
      }
    } else {
      _userPos = LocationService.defaultLocation;
    }
    _initBusStops();
    _loadRealBusStops();
    _detectLocation();
  }

  void _fetchOlaEtasIfNeeded(int index) {
    if (index < 0 || index >= _busStops.length) return;
    if (_olaBikeDurationCache.containsKey(index) && _olaWalkDurationCache.containsKey(index)) return;
    if (_fetchingEtaForIndex == index) return;
    _fetchingEtaForIndex = index;

    final stop = _busStops[index];
    final basePos = _userPos ?? LocationService.defaultLocation;
    final dest = LatLng((stop['lat'] as num).toDouble(), (stop['lng'] as num).toDouble());

    Future.microtask(() async {
      try {
        final bikeRes = await OlaMapsService.getDirections(
          origin: basePos,
          destination: dest,
          mode: 'driving',
        );
        if (mounted && bikeRes != null && bikeRes.readableDuration.isNotEmpty) {
          setState(() {
            _olaBikeDurationCache[index] = bikeRes.readableDuration;
          });
        }
      } catch (_) {}

      try {
        final walkRes = await OlaMapsService.getDirections(
          origin: basePos,
          destination: dest,
          mode: 'walking',
        );
        if (mounted && walkRes != null && walkRes.readableDuration.isNotEmpty) {
          setState(() {
            _olaWalkDurationCache[index] = walkRes.readableDuration;
          });
        }
      } catch (_) {}
    });
  }

  void _initBusStops() {
    final basePos = _userPos ?? LocationService.defaultLocation;
    _busStops = [
      {
        'title': 'Bus Stop (Locating...)',
        'address': 'Searching nearby bus stops...',
        'lat': basePos.latitude + 0.0010,
        'lng': basePos.longitude - 0.0008,
        'distance': '...',
      },
      {
        'title': 'Bus Stop (Locating...)',
        'address': 'Searching nearby bus stops...',
        'lat': basePos.latitude - 0.0018,
        'lng': basePos.longitude + 0.0015,
        'distance': '...',
      },
      {
        'title': 'Bus Stop (Locating...)',
        'address': 'Searching nearby bus stops...',
        'lat': basePos.latitude + 0.0028,
        'lng': basePos.longitude + 0.0022,
        'distance': '...',
      },
    ];

    _updateRealtimeDistances();
  }

  void _updateRealtimeDistances() {
    final basePos = _userPos ?? LocationService.defaultLocation;
    for (var stop in _busStops) {
      final dist = LocationService.calculateDistance(
        basePos.latitude,
        basePos.longitude,
        stop['lat'] as double,
        stop['lng'] as double,
      );
      stop['distance'] = LocationService.formatDistance(dist);
    }
  }

  Future<void> _loadRealBusStops() async {
    final basePos = _userPos ?? LocationService.defaultLocation;
    final realPlaces = await LocationService.fetchRealNearbyFacilities(
      keyword: 'bus stop',
      center: basePos,
      fallbackCategory: 'Bus Stop',
    );

    if (!mounted) return;
    if (realPlaces.isNotEmpty) {
      setState(() {
        _busStops = realPlaces;
      });
    }
  }

  Future<void> _detectLocation() async {
    // If manual location is active, don't override it with GPS
    if (_isManualLocation) return;

    final Position? pos = await LocationService.getCurrentPosition(requestPermission: false);
    final LatLng activePos = pos != null
        ? LatLng(pos.latitude, pos.longitude)
        : LocationService.defaultLocation;

    if (mounted) {
      final bool shifted = _userPos == null ||
          ((_userPos!.latitude - activePos.latitude).abs() > 0.0005 ||
              (_userPos!.longitude - activePos.longitude).abs() > 0.0005);
      setState(() {
        _userPos = activePos;
        _locationLabel = 'Your Location';
        _isManualLocation = false;
        _updateRealtimeDistances();
      });
      if (shifted) {
        _loadRealBusStops();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return BlocBuilder<BusStopBloc, BusStopState>(
      builder: (context, state) {
        final BusStopFlowState flowState = state.flowState;
        final bool isWalkMode = state.isWalkMode;
        final int selectedBusStopIndex = state.selectedIndex;

        return Scaffold(
          backgroundColor: AppColors.screenColor,
          body: CommonBackground(
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  // 1. Map underlay using CommonMap
                  Positioned.fill(
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: double.infinity,
                          height: flowState == BusStopFlowState.list
                              ? Responsive.h(280)
                              : MediaQuery.of(context).size.height - Responsive.h(100),
                          child: CommonMap(
                            mapState: flowState == BusStopFlowState.list
                                ? MapState.list
                                : flowState == BusStopFlowState.directions
                                    ? MapState.directions
                                    : MapState.navigation,
                            userLocationOverride: _isManualLocation ? _userPos : null,
                            isWalkMode: isWalkMode,
                            center: (flowState != BusStopFlowState.list && selectedBusStopIndex < _busStops.length)
                                ? LatLng(_busStops[selectedBusStopIndex]['lat'] as double, _busStops[selectedBusStopIndex]['lng'] as double)
                                : _userPos,
                            markers: _busStops.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final item = entry.value;
                              final isSelected = idx == selectedBusStopIndex && flowState != BusStopFlowState.list;
                              return Marker(
                                point: LatLng(item['lat'] as double, item['lng'] as double),
                                width: 38,
                                height: 38,
                                child: GestureDetector(
                                  onTap: () {
                                    context.read<BusStopBloc>().add(SelectBusStopEvent(idx));
                                    if (flowState == BusStopFlowState.list) {
                                      context.read<BusStopBloc>().add(ChangeBusStopFlowStateEvent(BusStopFlowState.directions));
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primary,
                                        width: 2,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.directions_bus,
                                      color: isSelected ? Colors.white : AppColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        if (flowState == BusStopFlowState.list) const Spacer(),
                      ],
                    ),
                  ),

                  // 2. Circle Back Button & Location Picker overlay (visible in list & directions modes)
                  if (flowState != BusStopFlowState.navigation)
                    Positioned(
                      top: Responsive.h(10),
                      left: Responsive.w(20),
                      right: Responsive.w(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (flowState == BusStopFlowState.directions) {
                                      context.read<BusStopBloc>().add(ChangeBusStopFlowStateEvent(BusStopFlowState.list));
                                    } else {
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: Container(
                                    width: Responsive.w(44),
                                    height: Responsive.w(44),
                                    decoration: BoxDecoration(
                                      color: AppColors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.outliner,
                                        width: Responsive.w(1.5),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.chevron_left,
                                      color: AppColors.black,
                                      size: Responsive.w(24),
                                    ),
                                  ),
                                ),
                                SizedBox(width: Responsive.w(12)),
                                if (flowState == BusStopFlowState.list)
                                  Expanded(
                                    child: CustomText.header(
                                      'Near Bus Stop',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.black,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (flowState == BusStopFlowState.directions)
                                  Expanded(
                                    child: CustomText.header(
                                      'Directions',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.black,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (flowState == BusStopFlowState.list) ...[
                            SizedBox(width: Responsive.w(8)),
                            _buildLocationPickerBadge(),
                          ],
                        ],
                      ),
                    ),

                  // 3. Conditional Flow Layout Overlays
                  _buildContentOverlay(context, screenWidth, flowState, isWalkMode, selectedBusStopIndex),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentOverlay(BuildContext context, double screenWidth, BusStopFlowState flowState, bool isWalkMode, int selectedIndex) {
    switch (flowState) {
      case BusStopFlowState.list:
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          top: Responsive.h(290), // Sits below the map
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(20),
              vertical: Responsive.h(12),
            ),
            itemCount: _busStops.length,
            itemBuilder: (context, index) {
              final busStop = _busStops[index];
              return Padding(
                padding: EdgeInsets.only(bottom: Responsive.h(12)),
                child: _buildBusStopCard(context, busStop, index),
              );
            },
          ),
        );

      case BusStopFlowState.directions:
        final basePos = _userPos ?? LocationService.defaultLocation;
        final currentStop = (selectedIndex >= 0 && selectedIndex < _busStops.length)
            ? _busStops[selectedIndex]
            : null;
        final double distMeters = currentStop != null
            ? LocationService.calculateDistance(
                basePos.latitude,
                basePos.longitude,
                (currentStop['lat'] as num).toDouble(),
                (currentStop['lng'] as num).toDouble(),
              )
            : 350.0;

        final int bikeEtaMins = LocationService.calculateEtaMinutes(distMeters, isWalking: false);
        final int walkEtaMins = LocationService.calculateEtaMinutes(distMeters, isWalking: true);

        final String bikeEtaStr = _olaBikeDurationCache[selectedIndex] ?? LocationService.formatEta(bikeEtaMins);
        final String walkEtaStr = _olaWalkDurationCache[selectedIndex] ?? LocationService.formatEta(walkEtaMins);

        final String activeEtaStr = isWalkMode ? walkEtaStr : bikeEtaStr;
        final String displayDistance = (currentStop != null && currentStop['distance'] != null && currentStop['distance'] != '...')
            ? currentStop['distance'] as String
            : LocationService.formatDistance(distMeters);

        _fetchOlaEtasIfNeeded(selectedIndex);

        return Stack(
          children: [
            // Top Location search overview card
            Positioned(
              top: Responsive.h(70),
              left: Responsive.w(20),
              right: Responsive.w(20),
              child: Container(
                padding: EdgeInsets.all(Responsive.w(16)),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(Responsive.w(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: Responsive.w(10),
                          height: Responsive.w(10),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: Responsive.w(16)),
                        Expanded(
                           child: CustomText.title(
                             _isManualLocation ? _locationLabel : 'Your Location',
                             fontSize: 14,
                             maxLines: 1,
                             overflow: TextOverflow.ellipsis,
                           ),
                         ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: Responsive.w(4)),
                      child: Container(
                        width: Responsive.w(2),
                        height: Responsive.h(16),
                        color: Colors.grey.shade300,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: Responsive.w(14),
                        ),
                        SizedBox(width: Responsive.w(14)),
                        Expanded(
                          child: CustomText.title(
                            _busStops[selectedIndex]['title'] as String? ?? 'Near Bus Stop',
                            fontSize: 14,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Navigation details card
            Positioned(
              bottom: Responsive.h(20),
              left: Responsive.w(20),
              right: Responsive.w(20),
              child: Container(
                padding: EdgeInsets.all(Responsive.w(20)),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(Responsive.w(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.header(
                      isWalkMode ? 'Walk' : 'Two-wheeler',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    SizedBox(height: Responsive.h(16)),

                    // Mode selectors with dynamic real-time durations
                    Row(
                      children: [
                        Expanded(
                          child: _buildModeTab(
                            icon: Icons.motorcycle,
                            label: bikeEtaStr,
                            isSelected: !isWalkMode,
                            onTap: () {
                              context.read<BusStopBloc>().add(ChangeBusStopWalkModeEvent(false));
                            },
                          ),
                        ),
                        SizedBox(width: Responsive.w(12)),
                        Expanded(
                          child: _buildModeTab(
                            icon: Icons.directions_walk,
                            label: walkEtaStr,
                            isSelected: isWalkMode,
                            onTap: () {
                              context.read<BusStopBloc>().add(ChangeBusStopWalkModeEvent(true));
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(12)),

                    // Distance/Time summary text
                    CustomText.title(
                      '$activeEtaStr ($displayDistance)',
                      color: const Color(0xFF4CAF50),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    SizedBox(height: Responsive.h(20)),

                    // Action Start button
                    GestureDetector(
                      onTap: () {
                        if (selectedIndex < _busStops.length) {
                          final stop = _busStops[selectedIndex];
                          Navigator.of(context).pushNamed(
                            RouteConstants.directions,
                            arguments: {
                              'title': stop['title'] as String? ?? 'Near Bus Stop',
                              'address': stop['address'] as String? ?? '',
                              'destinationCoords': LatLng(
                                (stop['lat'] as num).toDouble(),
                                (stop['lng'] as num).toDouble(),
                              ),
                              // Pass current userPos (live GPS or manual pick) as origin
                              'originCoords': _userPos,
                              'isWalkMode': isWalkMode,
                            },
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: Responsive.h(50),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(Responsive.w(25)),
                          border: Border.all(
                            color: AppColors.primary,
                            width: Responsive.w(1.5),
                          ),
                        ),
                        child: Center(
                          child: CustomText.title(
                            'Start',
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      case BusStopFlowState.navigation:
        final basePos = _userPos ?? LocationService.defaultLocation;
        final currentStop = (selectedIndex >= 0 && selectedIndex < _busStops.length)
            ? _busStops[selectedIndex]
            : null;
        final double distMeters = currentStop != null
            ? LocationService.calculateDistance(
                basePos.latitude,
                basePos.longitude,
                (currentStop['lat'] as num).toDouble(),
                (currentStop['lng'] as num).toDouble(),
              )
            : 350.0;

        final int activeMins = LocationService.calculateEtaMinutes(distMeters, isWalking: isWalkMode);
        final String activeEtaStr = isWalkMode
            ? (_olaWalkDurationCache[selectedIndex] ?? LocationService.formatEta(activeMins))
            : (_olaBikeDurationCache[selectedIndex] ?? LocationService.formatEta(activeMins));
        final String displayDistance = (currentStop != null && currentStop['distance'] != null && currentStop['distance'] != '...')
            ? currentStop['distance'] as String
            : LocationService.formatDistance(distMeters);
        final String arrivalTime = LocationService.formatArrivalTime(activeMins);

        return Stack(
          children: [
            // Top Instruction Card Overlay
            Positioned(
              top: Responsive.h(20),
              left: Responsive.w(20),
              right: Responsive.w(20),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(20),
                  vertical: Responsive.h(16),
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(Responsive.w(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: Responsive.w(36),
                      height: Responsive.w(36),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF2EC),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.navigation_outlined,
                        color: AppColors.primary,
                        size: Responsive.w(18),
                      ),
                    ),
                    SizedBox(width: Responsive.w(16)),
                    Expanded(
                      child: CustomText.title(
                        'towards 15th Cross Road',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Navigation details overlay
            Positioned(
              bottom: Responsive.h(20),
              left: Responsive.w(20),
              right: Responsive.w(20),
              child: Row(
                children: [
                  // Cancel button
                  GestureDetector(
                    onTap: () {
                      context.read<BusStopBloc>().add(ChangeBusStopFlowStateEvent(BusStopFlowState.directions));
                    },
                    child: Container(
                      width: Responsive.w(48),
                      height: Responsive.w(48),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.outliner, width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                          )
                        ],
                      ),
                      child: Icon(
                        Icons.close,
                        color: AppColors.black,
                        size: Responsive.w(20),
                      ),
                    ),
                  ),
                  SizedBox(width: Responsive.w(12)),

                  // Center time progress bubble with dynamic real-time data
                  Expanded(
                    child: Container(
                      height: Responsive.h(48),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(Responsive.w(24)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                          )
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomText.title(
                              activeEtaStr,
                              color: const Color(0xFF4CAF50),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            SizedBox(width: Responsive.w(8)),
                            CustomText.subtitle(
                              '($displayDistance) · $arrivalTime',
                              fontSize: 12,
                              color: AppColors.grayFont,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: Responsive.w(12)),

                  // Compass/Layers button
                  Container(
                    width: Responsive.w(48),
                    height: Responsive.w(48),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.outliner, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                        )
                      ],
                    ),
                    child: Icon(
                      Icons.navigation,
                      color: AppColors.primary,
                      size: Responsive.w(20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildModeTab({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final cleanLabel = LocationService.cleanDurationString(label);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: Responsive.h(48),
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(6)),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF2EC) : AppColors.white,
          borderRadius: BorderRadius.circular(Responsive.w(16)),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outliner.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.grayFont,
              size: Responsive.w(20),
            ),
            SizedBox(width: Responsive.w(6)),
            Flexible(
              child: CustomText.title(
                cleanLabel,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : AppColors.grayFont,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusStopCard(BuildContext context, Map<String, dynamic> busStop, int index) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        border: Border.all(
          color: AppColors.outliner,
          width: Responsive.w(1.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText.title(
            busStop['title'],
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          SizedBox(height: Responsive.h(4)),
          CustomText.subtitle(
            'Bus Stop - ${busStop['distance']}',
            fontSize: 12,
            color: AppColors.grayFont,
          ),
          SizedBox(height: Responsive.h(12)),
          GestureDetector(
            onTap: () {
              context.read<BusStopBloc>().add(ChangeBusStopFlowStateEvent(BusStopFlowState.directions));
              context.read<BusStopBloc>().add(SelectBusStopEvent(index));
            },
            child: Container(
              height: Responsive.h(36),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(Responsive.w(18)),
                border: Border.all(
                  color: AppColors.primary,
                  width: Responsive.w(1.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.navigation,
                    color: AppColors.primary,
                    size: Responsive.w(14),
                  ),
                  SizedBox(width: Responsive.w(8)),
                  CustomText.title(
                    'Directions',
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPickerBadge() {
    final hasManual = LocationService.hasManualLocation;
    return GestureDetector(
      onTap: _openLocationPickerSheet,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(10),
          vertical: Responsive.h(6),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Responsive.w(20)),
          border: Border.all(
            color: hasManual ? const Color(0xFFF57F17) : AppColors.primary,
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasManual ? Icons.edit_location_alt : Icons.my_location,
              size: 14,
              color: hasManual ? const Color(0xFFF57F17) : AppColors.primary,
            ),
            SizedBox(width: Responsive.w(4)),
            Text(
              hasManual ? 'Manual' : 'Live GPS',
              style: TextStyle(
                color: hasManual ? const Color(0xFFF57F17) : AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: Responsive.w(2)),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: hasManual ? const Color(0xFFF57F17) : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
  

  Future<void> _openLocationPickerSheet() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.w(20),
            vertical: Responsive.h(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change Bus Stop Search Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
              SizedBox(height: Responsive.h(12)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.my_location, color: Color(0xFF2E7D32)),
                ),
                title: const Text('Use Live GPS Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Find bus stops near your live device coordinates', style: TextStyle(fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final pos = await LocationService.switchToLiveGps();
                  if (pos != null && mounted) {
                    setState(() {
                      _userPos = LatLng(pos.latitude, pos.longitude);
                      _updateRealtimeDistances();
                    });
                    _loadRealBusStops();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Switched to Live GPS location'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF3E0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.map_outlined, color: Color(0xFFE65100)),
                ),
                title: const Text('Pick on Map / Search Area', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Search any landmark, city, or drop a pin', style: TextStyle(fontSize: 12)),
                onTap: () async {
                  if (_isNavigating) return;
                  _isNavigating = true;
                  Navigator.pop(ctx);
                  try {
                    final result = await Navigator.pushNamed(context, RouteConstants.pickLocation);
                    if (result is Map<String, dynamic>) {
                      final isGps = result['isGps'] == true;
                      if (isGps) {
                        final pos = await LocationService.switchToLiveGps();
                        if (pos != null && mounted) {
                          setState(() {
                            _userPos = LatLng(pos.latitude, pos.longitude);
                            _updateRealtimeDistances();
                          });
                          _loadRealBusStops();
                        }
                      } else if (result['latLng'] != null) {
                        final latLng = result['latLng'] as LatLng;
                        final addr = (result['address'] as String?) ?? 'Manual Location';
                        await HiveService.setManualLocation(
                          latitude: latLng.latitude,
                          longitude: latLng.longitude,
                          address: addr,
                        );
                        if (mounted) {
                          setState(() {
                            _userPos = latLng;
                            _isManualLocation = true;
                            _locationLabel = addr;
                            // Clear ETA cache — will re-fetch for new origin
                            _olaBikeDurationCache.clear();
                            _olaWalkDurationCache.clear();
                            _fetchingEtaForIndex = null;
                            _updateRealtimeDistances();
                          });
                          _loadRealBusStops();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Updated bus stop location to: $addr'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    }
                  } finally {
                    _isNavigating = false;
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
