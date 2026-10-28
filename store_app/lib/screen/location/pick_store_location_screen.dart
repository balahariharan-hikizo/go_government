import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../constants/google_config.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';
import '../../services/location_service.dart';

class PickStoreLocationScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialAddress;

  const PickStoreLocationScreen({
    super.key,
    this.initialLocation,
    this.initialAddress,
  });

  @override
  State<PickStoreLocationScreen> createState() => _PickStoreLocationScreenState();
}

class _PickStoreLocationScreenState extends State<PickStoreLocationScreen> {
  late final MapController _mapController;
  final TextEditingController _searchController = TextEditingController();
  late LatLng _currentLocation;
  String _currentAddress = 'Detecting address...';
  String _currentPincode = '';
  String _currentArea = '';
  String _currentCity = '';
  bool _isLoadingAddress = false;
  LatLng? _userGpsPoint;
  Timer? _debounceTimer;

  // Search state
  List<PlaceSearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentLocation = widget.initialLocation ?? LocationService.defaultLocation;
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _currentAddress = widget.initialAddress!;
      _searchController.text = widget.initialAddress!;
    }

    _fetchGpsAndGeocode();
  }

  void _onSearchQueryChanged(String query) {
    _searchDebounce?.cancel();
    final clean = query.trim();
    if (clean.length < 2) {
      if (_searchResults.isNotEmpty || _isSearching) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await LocationService.searchPlaces(clean);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    });
  }

  void _selectSearchResult(PlaceSearchResult place) {
    FocusScope.of(context).unfocus();
    final point = LatLng(place.latitude, place.longitude);
    setState(() {
      _currentLocation = point;
      _searchResults = [];
      _searchController.text = place.title;
    });
    try {
      _mapController.move(point, 16.5);
    } catch (_) {}
    _geocodePosition(point);
  }

  Future<void> _fetchGpsAndGeocode() async {
    if (widget.initialLocation == null) {
      _useDeviceGps();
    } else {
      _geocodePosition(_currentLocation);
    }
  }

  Future<void> _useDeviceGps() async {
    setState(() => _isLoadingAddress = true);
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;

    if (pos != null) {
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _userGpsPoint = latLng;
        _currentLocation = latLng;
      });
      try {
        _mapController.move(latLng, 16.5);
      } catch (_) {}
      await _geocodePosition(latLng);
    } else {
      await _geocodePosition(_currentLocation);
    }
  }

  Future<void> _geocodePosition(LatLng pos) async {
    setState(() => _isLoadingAddress = true);
    final result = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
    if (!mounted) return;

    setState(() {
      _isLoadingAddress = false;
      _currentAddress = result.address;
      _currentPincode = result.pincode;
      _currentArea = result.area;
      _currentCity = result.city;
      if (_searchController.text.isEmpty) {
        _searchController.text = result.area.isNotEmpty ? result.area : result.city;
      }
    });
  }

  void _onMapTapped(LatLng tapped) {
    FocusScope.of(context).unfocus();
    setState(() {
      _currentLocation = tapped;
      _searchResults = [];
    });
    try {
      _mapController.move(tapped, _mapController.camera.zoom);
    } catch (_) {}

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _geocodePosition(tapped);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _debounceTimer?.cancel();
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
                    initialCenter: _currentLocation,
                    initialZoom: 16.0,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                    onTap: (_, point) => _onMapTapped(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: GoogleConfig.googleTileUrl,
                      subdomains: GoogleConfig.googleTileSubdomains,
                      maxZoom: 20,
                      userAgentPackageName: 'com.hikizo.storeapp',
                    ),
                    // Live user GPS blue dot
                    if (_userGpsPoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _userGpsPoint!,
                            width: 26,
                            height: 26,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    // Selected Store Location Pin
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentLocation,
                          width: 52,
                          height: 52,
                          alignment: Alignment.topCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                              ),
                              CustomPaint(
                                size: const Size(10, 6),
                                painter: _TrianglePainter(color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Top Search Bar & Suggestions Overlay
              Positioned(
                top: Responsive.h(12),
                left: Responsive.w(16),
                right: Responsive.w(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(6), vertical: Responsive.h(4)),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(Responsive.w(16)),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.black),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchQueryChanged,
                              style: TextStyle(
                                fontSize: Responsive.sp(14),
                                fontWeight: FontWeight.w500,
                                color: AppColors.black,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search area, street, landmark...',
                                hintStyle: TextStyle(
                                  fontSize: Responsive.sp(13),
                                  color: AppColors.grayFont.withValues(alpha: 0.7),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: Responsive.h(10)),
                              ),
                            ),
                          ),
                          if (_isSearching)
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: Responsive.w(10)),
                              child: const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              ),
                            )
                          else if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.grayFont),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          else
                            Padding(
                              padding: EdgeInsets.only(right: Responsive.w(10)),
                              child: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
                            ),
                        ],
                      ),
                    ),

                    // Dropdown Search Predictions
                    if (_searchResults.isNotEmpty) ...[
                      SizedBox(height: Responsive.h(8)),
                      Container(
                        constraints: BoxConstraints(maxHeight: Responsive.h(240)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(Responsive.w(16)),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 14, offset: Offset(0, 6)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Responsive.w(16)),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.outliner.withValues(alpha: 0.4)),
                            itemBuilder: (context, index) {
                              final place = _searchResults[index];
                              return ListTile(
                                dense: true,
                                leading: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 16),
                                ),
                                title: Text(
                                  place.title,
                                  style: TextStyle(
                                    fontSize: Responsive.sp(13),
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: place.subtitle.isNotEmpty
                                    ? Text(
                                        place.subtitle,
                                        style: TextStyle(fontSize: Responsive.sp(11), color: AppColors.grayFont),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                onTap: () => _selectSearchResult(place),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 3. Floating "Current GPS" Button
              Positioned(
                right: Responsive.w(16),
                bottom: Responsive.h(230),
                child: FloatingActionButton.extended(
                  heroTag: 'gps_recenter_btn',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(24))),
                  icon: const Icon(Icons.my_location_rounded, size: 18, color: AppColors.primary),
                  label: CustomText.title('Current GPS', fontSize: 12, color: AppColors.primary),
                  onPressed: _useDeviceGps,
                ),
              ),

              // 4. Bottom Location Confirmation Card
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    Responsive.w(20),
                    Responsive.h(20),
                    Responsive.w(20),
                    Responsive.h(28),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(Responsive.w(24))),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(Responsive.w(10)),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(Responsive.w(12)),
                            ),
                            child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 22),
                          ),
                          SizedBox(width: Responsive.w(12)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomText.title(
                                  _isLoadingAddress ? 'Resolving Address...' : 'Selected Store Location',
                                  fontSize: 14,
                                  color: AppColors.black,
                                ),
                                SizedBox(height: Responsive.h(4)),
                                if (_isLoadingAddress)
                                  const LinearProgressIndicator(color: AppColors.primary, minHeight: 2)
                                else
                                  CustomText.body(
                                    _currentAddress,
                                    fontSize: 12,
                                    color: AppColors.grayFont,
                                    maxLines: 2,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: Responsive.h(12)),

                      // GPS Coordinate & Pincode Chips
                      Wrap(
                        spacing: Responsive.w(8),
                        runSpacing: Responsive.h(6),
                        children: [
                          _buildChip(
                            Icons.explore_outlined,
                            '${_currentLocation.latitude.toStringAsFixed(4)}, ${_currentLocation.longitude.toStringAsFixed(4)}',
                          ),
                          if (_currentPincode.isNotEmpty)
                            _buildChip(Icons.pin_drop_outlined, 'Pincode: $_currentPincode'),
                          if (_currentArea.isNotEmpty)
                            _buildChip(Icons.location_city_outlined, _currentArea),
                        ],
                      ),
                      SizedBox(height: Responsive.h(16)),

                      // Confirm Location Button
                      SizedBox(
                        width: double.infinity,
                        height: Responsive.h(50),
                        child: ElevatedButton(
                          onPressed: _isLoadingAddress
                              ? null
                              : () {
                                  final result = StoreLocationResult(
                                    latitude: _currentLocation.latitude,
                                    longitude: _currentLocation.longitude,
                                    address: _currentAddress,
                                    pincode: _currentPincode,
                                    area: _currentArea,
                                    city: _currentCity,
                                  );
                                  Navigator.of(context).pop(result);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Responsive.w(14)),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              SizedBox(width: Responsive.w(8)),
                              CustomText.title('Confirm Shop Location', fontSize: 15, color: Colors.white),
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

  Widget _buildChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(10), vertical: Responsive.h(5)),
      decoration: BoxDecoration(
        color: AppColors.screenColor,
        borderRadius: BorderRadius.circular(Responsive.w(8)),
        border: Border.all(color: AppColors.outliner.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          SizedBox(width: Responsive.w(4)),
          Text(
            text,
            style: TextStyle(
              fontSize: Responsive.sp(11),
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
