import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/responsive_helper.dart';
import '../../../widget/common_background.dart';
import '../../../widget/custom_text.dart';
import '../../../widget/common_map.dart';
import '../../../bloc/toilet/toilet_bloc.dart';
import '../../../bloc/toilet/toilet_event.dart';
import '../../../bloc/toilet/toilet_state.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../service/location_service.dart';
import '../../../network/ola_maps_service.dart';
import '../../../constants/route_constants.dart';
import '../../../hive/hive_service.dart';

enum ToiletFlowState { list, directions, navigation }

class NearToiletScreen extends StatefulWidget {
  const NearToiletScreen({super.key});

  @override
  State<NearToiletScreen> createState() => _NearToiletScreenState();
}

class _NearToiletScreenState extends State<NearToiletScreen> {
  late List<Map<String, dynamic>> _toilets;
  LatLng? _userPos;
  String _locationLabel = 'Your Location';
  bool _isManualLocation = false;

  // Real-time ETA cache for selected items
  final Map<int, String> _olaBikeDurationCache = {};
  final Map<int, String> _olaWalkDurationCache = {};
  int? _fetchingEtaForIndex;

  @override
  void initState() {
    super.initState();
    // Load existing manual location if saved
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
    _initToilets();
    _loadRealToilets();
    _detectLocation();
  }

  void _fetchOlaEtasIfNeeded(int index) {
    if (index < 0 || index >= _toilets.length) return;
    if (_olaBikeDurationCache.containsKey(index) && _olaWalkDurationCache.containsKey(index)) return;
    if (_fetchingEtaForIndex == index) return;
    _fetchingEtaForIndex = index;

    final toilet = _toilets[index];
    final basePos = _userPos ?? LocationService.defaultLocation;
    final dest = LatLng((toilet['lat'] as num).toDouble(), (toilet['lng'] as num).toDouble());

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

  void _initToilets() {
    final basePos = _userPos ?? LocationService.defaultLocation;
    _toilets = [
      {
        'title': 'Public Toilet (Locating...)',
        'address': 'Searching nearby public restrooms...',
        'lat': basePos.latitude + 0.0018,
        'lng': basePos.longitude + 0.0012,
        'distance': '...',
      },
      {
        'title': 'Public Toilet (Locating...)',
        'address': 'Searching nearby public restrooms...',
        'lat': basePos.latitude - 0.0022,
        'lng': basePos.longitude + 0.0018,
        'distance': '...',
      },
      {
        'title': 'Public Toilet (Locating...)',
        'address': 'Searching nearby public restrooms...',
        'lat': basePos.latitude + 0.0035,
        'lng': basePos.longitude - 0.0025,
        'distance': '...',
      },
    ];

    _updateRealtimeDistances();
  }

  void _updateRealtimeDistances() {
    final basePos = _userPos ?? LocationService.defaultLocation;
    for (var toilet in _toilets) {
      final dist = LocationService.calculateDistance(
        basePos.latitude,
        basePos.longitude,
        toilet['lat'] as double,
        toilet['lng'] as double,
      );
      toilet['distance'] = LocationService.formatDistance(dist);
    }
  }

  Future<void> _loadRealToilets() async {
    final basePos = _userPos ?? LocationService.defaultLocation;
    final realPlaces = await LocationService.fetchRealNearbyFacilities(
      keyword: 'public toilet',
      center: basePos,
      fallbackCategory: 'Public Toilet',
    );

    if (!mounted) return;
    if (realPlaces.isNotEmpty) {
      setState(() {
        _toilets = realPlaces;
      });
    }
  }

  Future<void> _detectLocation() async {
    // If manual location is active, don't override with GPS
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
        _loadRealToilets();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return BlocBuilder<ToiletBloc, ToiletState>(
      builder: (context, state) {
        final ToiletFlowState flowState = state.flowState;
        final bool isWalkMode = state.isWalkMode;
        final int selectedToiletIndex = state.selectedIndex;

        return Scaffold(
          backgroundColor: AppColors.screenColor,
          body: CommonBackground(
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  // 1. Map Canvas (Full screen underlay)
                  Positioned.fill(
                    child: Column(
                      children: [
                        // Dynamic Map Height depending on flow state
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: double.infinity,
                          height: flowState == ToiletFlowState.list
                              ? Responsive.h(280)
                              : MediaQuery.of(context).size.height - Responsive.h(100),
                          child: CommonMap(
                            mapState: flowState == ToiletFlowState.list
                                ? MapState.list
                                : flowState == ToiletFlowState.directions
                                    ? MapState.directions
                                    : MapState.navigation,
                            isWalkMode: isWalkMode,
                            userLocationOverride: _isManualLocation ? _userPos : null,
                            center: (flowState != ToiletFlowState.list && selectedToiletIndex < _toilets.length)
                                ? LatLng(_toilets[selectedToiletIndex]['lat'] as double, _toilets[selectedToiletIndex]['lng'] as double)
                                : _userPos,
                            markers: _toilets.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final item = entry.value;
                              final isSelected = idx == selectedToiletIndex && flowState != ToiletFlowState.list;
                              return Marker(
                                point: LatLng(item['lat'] as double, item['lng'] as double),
                                width: 38,
                                height: 38,
                                child: GestureDetector(
                                  onTap: () {
                                    context.read<ToiletBloc>().add(SelectToiletEvent(idx));
                                    if (flowState == ToiletFlowState.list) {
                                      context.read<ToiletBloc>().add(ChangeToiletFlowStateEvent(ToiletFlowState.directions));
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
                                      Icons.wc,
                                      color: isSelected ? Colors.white : AppColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        if (flowState == ToiletFlowState.list) const Spacer(),
                      ],
                    ),
                  ),

                  // 2. Circle Back Button & Location Picker overlay (visible in list & directions modes)
                  if (flowState != ToiletFlowState.navigation)
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
                                    if (flowState == ToiletFlowState.directions) {
                                      context.read<ToiletBloc>().add(ChangeToiletFlowStateEvent(ToiletFlowState.list));
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
                                if (flowState == ToiletFlowState.list)
                                  Expanded(
                                    child: CustomText.header(
                                      'Near Toilet',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.black,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (flowState == ToiletFlowState.directions)
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
                          if (flowState == ToiletFlowState.list) ...[
                            SizedBox(width: Responsive.w(8)),
                            _buildLocationPickerBadge(),
                          ],
                        ],
                      ),
                    ),

                  // 3. Dynamic Card Overlays based on state
                  _buildContentOverlay(context, screenWidth, flowState, isWalkMode, selectedToiletIndex),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentOverlay(BuildContext context, double screenWidth, ToiletFlowState flowState, bool isWalkMode, int selectedIndex) {
    switch (flowState) {
      case ToiletFlowState.list:
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
            itemCount: _toilets.length,
            itemBuilder: (context, index) {
              final toilet = _toilets[index];
              return Padding(
                padding: EdgeInsets.only(bottom: Responsive.h(12)),
                child: _buildToiletCard(context, toilet, index),
              );
            },
          ),
        );

      case ToiletFlowState.directions:
        final basePos = _userPos ?? LocationService.defaultLocation;
        final currentFacility = (selectedIndex >= 0 && selectedIndex < _toilets.length)
            ? _toilets[selectedIndex]
            : null;
        final double distMeters = currentFacility != null
            ? LocationService.calculateDistance(
                basePos.latitude,
                basePos.longitude,
                (currentFacility['lat'] as num).toDouble(),
                (currentFacility['lng'] as num).toDouble(),
              )
            : 350.0;

        final int bikeEtaMins = LocationService.calculateEtaMinutes(distMeters, isWalking: false);
        final int walkEtaMins = LocationService.calculateEtaMinutes(distMeters, isWalking: true);

        final String bikeEtaStr = _olaBikeDurationCache[selectedIndex] ?? LocationService.formatEta(bikeEtaMins);
        final String walkEtaStr = _olaWalkDurationCache[selectedIndex] ?? LocationService.formatEta(walkEtaMins);

        final String activeEtaStr = isWalkMode ? walkEtaStr : bikeEtaStr;
        final String displayDistance = (currentFacility != null && currentFacility['distance'] != null && currentFacility['distance'] != '...')
            ? currentFacility['distance'] as String
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
                            _toilets[selectedIndex]['title'] as String? ?? 'Near Toilet',
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

                    // Mode selectors
                    Row(
                      children: [
                        Expanded(
                          child: _buildModeTab(
                            icon: Icons.motorcycle,
                            label: bikeEtaStr,
                            isSelected: !isWalkMode,
                            onTap: () {
                              context.read<ToiletBloc>().add(ChangeToiletWalkModeEvent(false));
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
                              context.read<ToiletBloc>().add(ChangeToiletWalkModeEvent(true));
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
                        if (selectedIndex < _toilets.length) {
                          final toilet = _toilets[selectedIndex];
                          Navigator.of(context).pushNamed(
                            RouteConstants.directions,
                            arguments: {
                              'title': toilet['title'] as String? ?? 'Near Toilet',
                              'address': toilet['address'] as String? ?? '',
                              'destinationCoords': LatLng(
                                (toilet['lat'] as num).toDouble(),
                                (toilet['lng'] as num).toDouble(),
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
                            fontSize: 15,
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

      case ToiletFlowState.navigation:
        final basePos = _userPos ?? LocationService.defaultLocation;
        final currentFacility = (selectedIndex >= 0 && selectedIndex < _toilets.length)
            ? _toilets[selectedIndex]
            : null;
        final double distMeters = currentFacility != null
            ? LocationService.calculateDistance(
                basePos.latitude,
                basePos.longitude,
                (currentFacility['lat'] as num).toDouble(),
                (currentFacility['lng'] as num).toDouble(),
              )
            : 350.0;

        final int activeMins = LocationService.calculateEtaMinutes(distMeters, isWalking: isWalkMode);
        final String activeEtaStr = isWalkMode
            ? (_olaWalkDurationCache[selectedIndex] ?? LocationService.formatEta(activeMins))
            : (_olaBikeDurationCache[selectedIndex] ?? LocationService.formatEta(activeMins));
        final String displayDistance = (currentFacility != null && currentFacility['distance'] != null && currentFacility['distance'] != '...')
            ? currentFacility['distance'] as String
            : LocationService.formatDistance(distMeters);
        final String arrivalTime = LocationService.formatArrivalTime(activeMins);

        return Stack(
          children: [
            // Top Navigation Instruction bar
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

            // Bottom Navigation HUD Controls
            Positioned(
              bottom: Responsive.h(30),
              left: Responsive.w(20),
              right: Responsive.w(20),
              child: Row(
                children: [
                  // Close Navigation button
                  GestureDetector(
                    onTap: () {
                      context.read<ToiletBloc>().add(ChangeToiletFlowStateEvent(ToiletFlowState.directions));
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

  Widget _buildToiletCard(BuildContext context, Map<String, dynamic> toilet, int index) {
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
            toilet['title'],
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          SizedBox(height: Responsive.h(4)),
          CustomText.subtitle(
            'Toilet - ${toilet['distance']}',
            fontSize: 12,
            color: AppColors.grayFont,
          ),
          SizedBox(height: Responsive.h(12)),
          GestureDetector(
            onTap: () {
              context.read<ToiletBloc>().add(ChangeToiletFlowStateEvent(ToiletFlowState.directions));
              context.read<ToiletBloc>().add(SelectToiletEvent(index));
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
                'Change Toilet Search Location',
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
                subtitle: const Text('Find public toilets near your live device coordinates', style: TextStyle(fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final bool isAvailable = await LocationService.isLocationAvailable();
                  if (!isAvailable) {
                    await LocationService.openAppropriateSettings();
                    return;
                  }
                  final pos = await LocationService.switchToLiveGps();
                  if (pos != null && mounted) {
                    setState(() {
                      _userPos = LatLng(pos.latitude, pos.longitude);
                      _updateRealtimeDistances();
                    });
                    _loadRealToilets();
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
                  Navigator.pop(ctx);
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
                        _loadRealToilets();
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
                          // Clear ETA cache - will re-fetch for new origin
                          _olaBikeDurationCache.clear();
                          _olaWalkDurationCache.clear();
                          _fetchingEtaForIndex = null;
                          _updateRealtimeDistances();
                        });
                        _loadRealToilets();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Updated toilet location to: $addr'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
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
