import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/admin_api_service.dart';
import '../../utils/responsive.dart';
import '../complaints/complaint_detail_dialog.dart';
import '../stores/store_detail_dialog.dart';

class CityMapTabView extends StatefulWidget {
  final Map<String, dynamic>? initialFocusEntity;
  const CityMapTabView({super.key, this.initialFocusEntity});

  @override
  State<CityMapTabView> createState() => CityMapTabViewState();
}

class CityMapTabViewState extends State<CityMapTabView> {
  final MapController _mapController = MapController();
  static const LatLng _defaultCenter = LatLng(0.0, 0.0); 

  bool _isLoading = true;
  List<Map<String, dynamic>> _complaints = [];
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _riders = [];

  // Live Officer GPS HQ Location
  LatLng? _myLocation;

  // Layer Toggles
  bool _showPending = true;
  bool _showInProgress = true;
  bool _showResolved = true;
  bool _showRiders = true;
  bool _showStores = true;

  // Selected Item for quick detail bottom card
  Map<String, dynamic>? _selectedEntity;

  // Incident Feed Filter
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showSidebar = true;
  String _sidebarTab = 'complaints'; // 'complaints', 'stores', 'riders'
  String _riderFilter = 'all'; // 'all', 'online', 'offline'
  bool _useOsmFallback = false;
  int _tileErrorCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialFocusEntity != null) {
      _selectedEntity = widget.initialFocusEntity;
    }
    reload();
  }

  @override
  void didUpdateWidget(covariant CityMapTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFocusEntity != null && widget.initialFocusEntity != oldWidget.initialFocusEntity) {
      setState(() {
        _selectedEntity = widget.initialFocusEntity;
      });
      _focusOnEntity(widget.initialFocusEntity!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _focusOnEntity(Map<String, dynamic> entity) {
    final type = entity['type'] as String?;
    final data = entity['data'] as Map<String, dynamic>? ?? {};

    LatLng? coords;
    if (type == 'complaint') {
      coords = _parseCoords(data['lat'], data['lng']);
    } else if (type == 'store') {
      coords = _parseCoords(data['location']?['lat'], data['location']?['lng']);
    } else if (type == 'rider') {
      coords = _parseCoords(
        data['latitude'] ?? data['lat'],
        data['longitude'] ?? data['lng'],
      );
    }

    if (coords != null) {
      _mapController.move(coords, 16.0);
    }
  }

  Future<void> reload() async {
    setState(() => _isLoading = true);

    try {
      final compFuture = AdminApiService.getAllComplaints();
      final storeFuture = AdminApiService.getAllStores();
      final riderFuture = AdminApiService.getLiveRiders();

      final results = await Future.wait([compFuture, storeFuture, riderFuture]);

      final compRes = results[0];
      final storeRes = results[1];
      final riderRes = results[2];

      if (!mounted) return;

      List<Map<String, dynamic>> comps = [];
      if (compRes['success'] == true && compRes['complaints'] != null) {
        comps = List<Map<String, dynamic>>.from(compRes['complaints']);
      }

      List<Map<String, dynamic>> strs = [];
      if (storeRes['success'] == true && storeRes['data'] != null) {
        strs = List<Map<String, dynamic>>.from(storeRes['data']['stores'] ?? []);
      }

      List<Map<String, dynamic>> rdrs = [];
      if (riderRes['success'] == true && riderRes['riders'] != null) {
        rdrs = List<Map<String, dynamic>>.from(riderRes['riders']);
      }

      setState(() {
        _complaints = comps;
        _stores = strs;
        _riders = rdrs;
        _isLoading = false;
      });

      // Auto-focus on initial entity if provided, otherwise fit all visible markers
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_selectedEntity != null) {
          _focusOnEntity(_selectedEntity!);
        } else {
          _fitAllVisiblePins(showToastOnEmpty: false);
        }
      });
    } catch (e) {
      debugPrint('⚠️ [CityMap] Error fetching map data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<LatLng> _getAllVisiblePoints() {
    final points = <LatLng>[];

    for (final c in _complaints) {
      final status = (c['status'] ?? 'Under Review').toString();
      final isPending = status.toLowerCase() == 'under review';
      final isInProgress = status.toLowerCase() == 'in progress';
      final isResolved = status.toLowerCase() == 'resolved';

      if (isPending && !_showPending) continue;
      if (isInProgress && !_showInProgress) continue;
      if (isResolved && !_showResolved) continue;
      if (!isPending && !isInProgress && !isResolved && !_showPending) continue;

      final coords = _parseCoords(c['lat'], c['lng']);
      if (coords != null) points.add(coords);
    }

    if (_showStores) {
      for (final s in _stores) {
        final loc = s['location'];
        final coords = _parseCoords(loc?['lat'], loc?['lng']);
        if (coords != null) points.add(coords);
      }
    }

    if (_showRiders) {
      for (final r in _riders) {
        final coords = _parseCoords(
          r['latitude'] ?? r['lat'],
          r['longitude'] ?? r['lng'],
        );
        if (coords != null) points.add(coords);
      }
    }

    return points;
  }

  // Recenter with Live GPS or fallback to fitting all pins
  Future<void> _handleRecenter() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(timeLimit: Duration(seconds: 6)),
        );
        final userLoc = LatLng(pos.latitude, pos.longitude);
        setState(() => _myLocation = userLoc);
        _mapController.move(userLoc, 15.0);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Centered on your live GPS location'),
              duration: Duration(seconds: 2),
              backgroundColor: Color(0xFF0284C7),
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('⚠️ [CityMap] Geolocation not granted or failed: $e');
    }

    // Fallback: Smart Fit to all visible pins
    _fitAllVisiblePins(showToastOnEmpty: true);
  }

  void _fitAllVisiblePins({bool showToastOnEmpty = true}) {
    final points = _getAllVisiblePoints();
    if (points.isEmpty) {
      _mapController.move(_defaultCenter, 12.0);
      if (showToastOnEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Reset to default municipal center (No active pins on map)'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF0F172A),
          ),
        );
      }
      return;
    }

    if (points.length == 1) {
      _mapController.move(points.first, 14.0);
      return;
    }

    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(70),
          maxZoom: 15.0,
        ),
      );
    } catch (_) {
      double latSum = 0;
      double lngSum = 0;
      for (final p in points) {
        latSum += p.latitude;
        lngSum += p.longitude;
      }
      final center = LatLng(latSum / points.length, lngSum / points.length);
      _mapController.move(center, 13.0);
    }
  }

  // Parse coordinates safely
  LatLng? _parseCoords(dynamic latVal, dynamic lngVal) {
    if (latVal == null || lngVal == null) return null;
    final lat = double.tryParse(latVal.toString());
    final lng = double.tryParse(lngVal.toString());
    if (lat == null || lng == null) return null;
    if (lat == 0.0 && lng == 0.0) return null;
    if (lat < -90.0 || lat > 90.0 || lng < -180.0 || lng > 180.0) return null;
    return LatLng(lat, lng);
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // 0. Live Officer GPS Location Marker (if detected)
    if (_myLocation != null) {
      markers.add(
        Marker(
          point: _myLocation!,
          width: 50,
          height: 50,
          child: Tooltip(
            message: 'My Current Location (HQ)',
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),
        ),
      );
    }

    // 1. Complaints Markers
    for (final c in _complaints) {
      final status = (c['status'] ?? 'Under Review').toString();
      final isPending = status.toLowerCase() == 'under review';
      final isInProgress = status.toLowerCase() == 'in progress';
      final isResolved = status.toLowerCase() == 'resolved';

      if (isPending && !_showPending) continue;
      if (isInProgress && !_showInProgress) continue;
      if (isResolved && !_showResolved) continue;
      if (!isPending && !isInProgress && !isResolved && !_showPending) continue;

      final coords = _parseCoords(c['lat'], c['lng']);
      if (coords == null) continue;

      Color markerColor;
      IconData markerIcon;
      if (isResolved) {
        markerColor = const Color(0xFF16A34A); // Green
        markerIcon = Icons.check_circle_rounded;
      } else if (isInProgress) {
        markerColor = const Color(0xFFD97706); // Amber
        markerIcon = Icons.engineering_rounded;
      } else {
        markerColor = const Color(0xFFDC2626); // Red
        markerIcon = Icons.priority_high_rounded;
      }

      markers.add(
        Marker(
          point: coords,
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedEntity = {'type': 'complaint', 'data': c};
              });
              _mapController.move(coords, 15.0);
            },
            child: Tooltip(
              message: '${c['complaintId'] ?? 'Incident'} - ${c['category'] ?? 'Complaint'} ($status)',
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: markerColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(markerIcon, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 2. Stores Markers
    if (_showStores) {
      for (final s in _stores) {
        final loc = s['location'];
        final coords = _parseCoords(loc?['lat'], loc?['lng']);
        if (coords == null) continue;

        markers.add(
          Marker(
            point: coords,
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedEntity = {'type': 'store', 'data': s};
                });
                _mapController.move(coords, 15.0);
              },
              child: Tooltip(
                message: '${s['name'] ?? 'Store'} (${s['category'] ?? 'Shop'})',
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5), // Indigo
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.storefront_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    // 3. Riders Markers (Both Online live GPS & Offline last-known location)
    if (_showRiders) {
      for (final r in _riders) {
        final coords = _parseCoords(
          r['latitude'] ?? r['lat'],
          r['longitude'] ?? r['lng'],
        );
        if (coords == null) continue;
        final isOnline = r['isOnline'] == true;
        final pinColor = isOnline ? const Color(0xFF0284C7) : const Color(0xFF475569);
        final statusDesc = isOnline ? '🟢 Online (Live GPS)' : '⚪ Offline (Last Known Location)';

        markers.add(
          Marker(
            point: coords,
            width: 42,
            height: 42,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedEntity = {'type': 'rider', 'data': r};
                });
                _mapController.move(coords, 15.0);
              },
              child: Tooltip(
                message: '${r['name'] ?? 'Rider'} · $statusDesc',
                child: Container(
                  decoration: BoxDecoration(
                    color: pinColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: pinColor.withValues(alpha: isOnline ? 0.45 : 0.25),
                        blurRadius: isOnline ? 10 : 5,
                        spreadRadius: isOnline ? 1.5 : 0.5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.two_wheeler_rounded, color: Colors.white, size: isOnline ? 20 : 18),
                        if (!isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: const Color(0xFF94A3B8),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  // Count summaries
  int get _pendingCount => _complaints.where((c) => (c['status'] ?? '').toString().toLowerCase() == 'under review').length;
  int get _inProgressCount => _complaints.where((c) => (c['status'] ?? '').toString().toLowerCase() == 'in progress').length;
  int get _resolvedCount => _complaints.where((c) => (c['status'] ?? '').toString().toLowerCase() == 'resolved').length;
  int get _onlineRidersCount => _riders.where((r) => r['isOnline'] == true).length;
  int get _offlineRidersCount => _riders.where((r) => r['isOnline'] != true).length;
  int get _ridersWithLocCount => _riders.where((r) => _parseCoords(r['latitude'] ?? r['lat'], r['longitude'] ?? r['lng']) != null).length;

  List<Map<String, dynamic>> get _filteredComplaintsFeed {
    return _complaints.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final id = (c['complaintId'] ?? '').toString().toLowerCase();
      final name = (c['userName'] ?? '').toString().toLowerCase();
      final cat = (c['category'] ?? '').toString().toLowerCase();
      final addr = (c['userAddress'] ?? '').toString().toLowerCase();
      final desc = (c['description'] ?? '').toString().toLowerCase();
      return id.contains(q) || name.contains(q) || cat.contains(q) || addr.contains(q) || desc.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredStoresFeed {
    return _stores.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (s['name'] ?? '').toString().toLowerCase();
      final owner = (s['ownerName'] ?? '').toString().toLowerCase();
      final cat = (s['category'] ?? '').toString().toLowerCase();
      final addr = (s['address'] ?? '').toString().toLowerCase();
      return name.contains(q) || owner.contains(q) || cat.contains(q) || addr.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredRidersFeed {
    final list = _riders.where((r) {
      final isOnline = r['isOnline'] == true;
      if (_riderFilter == 'online' && !isOnline) return false;
      if (_riderFilter == 'offline' && isOnline) return false;

      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (r['name'] ?? '').toString().toLowerCase();
      final phone = (r['phone'] ?? '').toString().toLowerCase();
      final vehicle = (r['vehicleType'] ?? '').toString().toLowerCase();
      final id = (r['riderId'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q) || vehicle.contains(q) || id.contains(q);
    }).toList();

    // Sort: Online riders 1st, then riders with valid GPS, then alphabetical
    list.sort((a, b) {
      final aOnline = a['isOnline'] == true ? 1 : 0;
      final bOnline = b['isOnline'] == true ? 1 : 0;
      if (aOnline != bOnline) {
        return bOnline.compareTo(aOnline); // 1 (Online) comes before 0 (Offline)
      }

      final aHasLoc = (_parseCoords(a['latitude'] ?? a['lat'], a['longitude'] ?? a['lng']) != null) ? 1 : 0;
      final bHasLoc = (_parseCoords(b['latitude'] ?? b['lat'], b['longitude'] ?? b['lng']) != null) ? 1 : 0;
      if (aHasLoc != bHasLoc) {
        return bHasLoc.compareTo(aHasLoc);
      }

      final aName = (a['name'] ?? '').toString().toLowerCase();
      final bName = (b['name'] ?? '').toString().toLowerCase();
      return aName.compareTo(bName);
    });

    return list;
  }

  void _zoomToEntity(String type, Map<String, dynamic> item) {
    LatLng? coords;
    if (type == 'complaint') {
      coords = _parseCoords(item['lat'], item['lng']);
    } else if (type == 'store') {
      coords = _parseCoords(item['location']?['lat'], item['location']?['lng']);
    } else if (type == 'rider') {
      coords = _parseCoords(
        item['latitude'] ?? item['lat'],
        item['longitude'] ?? item['lng'],
      );
    }

    if (coords != null) {
      setState(() {
        _selectedEntity = {'type': type, 'data': item};
      });
      _mapController.move(coords, 16.0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Location coordinates not available for this $type'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;

    return Stack(
      children: [
        // ─── 1. Map Layer ───────────────────────────────────────────
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 12.0,
              minZoom: 4.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                key: ValueKey(_useOsmFallback),
                urlTemplate: _useOsmFallback
                    ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                    : 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                subdomains: _useOsmFallback ? const ['a', 'b', 'c'] : const ['0', '1', '2', '3'],
                userAgentPackageName: 'com.gogovernment.admin',
                tileProvider: CancellableNetworkTileProvider(),
                errorTileCallback: (tile, error, stackTrace) {
                  if (!_useOsmFallback) {
                    _tileErrorCount++;
                    if (_tileErrorCount >= 4) {
                      debugPrint('⚠️ [CityMap] Google tiles error detected ($error). Falling back to OpenStreetMap.');
                      setState(() {
                        _useOsmFallback = true;
                        _tileErrorCount = 0;
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ Google Map tiles unavailable. Auto-switched to OpenStreetMap fallback.'),
                            backgroundColor: Color(0xFF0F172A),
                            duration: Duration(seconds: 4),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
        ),

        // ─── 2. Top-Left: Incident Search & Multi-Feed Drawer ───────
        if (isDesktop && _showSidebar)
          Positioned(
            top: 20,
            left: 20,
            bottom: 20,
            width: 360,
            child: _buildSideMultiFeedPanel(),
          ),

        // Toggle Sidebar Button (Desktop)
        if (isDesktop)
          Positioned(
            top: 20,
            left: _showSidebar ? 388 : 20,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              elevation: 4,
              child: IconButton(
                icon: Icon(
                  _showSidebar ? Icons.chevron_left_rounded : Icons.view_sidebar_rounded,
                  color: const Color(0xFF0F172A),
                ),
                tooltip: _showSidebar ? 'Hide Incidents List' : 'Show Incidents List',
                onPressed: () => setState(() => _showSidebar = !_showSidebar),
              ),
            ),
          ),

        // ─── 3. Top-Right: Map Control & Layer Switcher Panel ──────
        Positioned(
          top: 20,
          right: 20,
          child: _buildLayerControlPanel(),
        ),

        // ─── 4. Selected Entity Inspection Bottom Card ─────────────
        if (_selectedEntity != null)
          Positioned(
            left: isDesktop && _showSidebar ? 400 : 20,
            right: 20,
            bottom: 20,
            child: _buildSelectedInspectionCard(),
          ),

        // ─── 5. Loading Indicator Overlay ─────────────────────────
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.25),
              child: const Center(
                child: Card(
                  color: Color(0xFF0F172A),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF38BDF8)),
                        ),
                        SizedBox(width: 14),
                        Text(
                          'Synchronizing Smart City GIS Layers...',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Widget: Layer Control Panel (Top-Right) ─────────────────────
  Widget _buildLayerControlPanel() {
    return Container(
      width: 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.layers_rounded, color: Color(0xFF38BDF8), size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Command Layers',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _useOsmFallback ? Icons.public_rounded : Icons.map_rounded,
                      color: _useOsmFallback ? const Color(0xFF38BDF8) : const Color(0xFF22C55E),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _useOsmFallback ? 'OSM Fallback' : 'Google Maps',
                      style: TextStyle(
                        color: _useOsmFallback ? const Color(0xFF38BDF8) : const Color(0xFF22C55E),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Layer Switch Toggles
          _buildLayerToggle(
            label: 'Pending Grievances',
            color: const Color(0xFFDC2626),
            count: _pendingCount,
            value: _showPending,
            onChanged: (v) => setState(() => _showPending = v),
          ),
          _buildLayerToggle(
            label: 'In-Progress Works',
            color: const Color(0xFFD97706),
            count: _inProgressCount,
            value: _showInProgress,
            onChanged: (v) => setState(() => _showInProgress = v),
          ),
          _buildLayerToggle(
            label: 'Resolved Works',
            color: const Color(0xFF16A34A),
            count: _resolvedCount,
            value: _showResolved,
            onChanged: (v) => setState(() => _showResolved = v),
          ),
          _buildLayerToggle(
            label: 'Rider Fleet & Logistics',
            color: const Color(0xFF0284C7),
            count: _ridersWithLocCount,
            value: _showRiders,
            onChanged: (v) => setState(() => _showRiders = v),
          ),
          _buildLayerToggle(
            label: 'Municipal Stores',
            color: const Color(0xFF4F46E5),
            count: _stores.length,
            value: _showStores,
            onChanged: (v) => setState(() => _showStores = v),
          ),

          const SizedBox(height: 10),
          const Divider(color: Color(0xFF334155), height: 16),

          // Action Buttons: Live GPS Recenter & Zoom
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.my_location_rounded, size: 14),
                  label: const Text('Live GPS / Fit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: _handleRecenter,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                tooltip: 'Zoom In',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final zoom = _mapController.camera.zoom;
                  _mapController.move(_mapController.camera.center, zoom + 1);
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.remove, size: 16, color: Colors.white),
                tooltip: 'Zoom Out',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final zoom = _mapController.camera.zoom;
                  _mapController.move(_mapController.camera.center, zoom - 1);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLayerToggle({
    required String label,
    required Color color,
    required int count,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: value ? Colors.white : Colors.grey,
                    fontSize: 12,
                    fontWeight: value ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 20,
                width: 32,
                child: Switch(
                  value: value,
                  activeThumbColor: const Color(0xFF38BDF8),
                  activeTrackColor: const Color(0xFF0284C7).withValues(alpha: 0.4),
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: const Color(0xFF334155),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Widget: Desktop Multi-Category Feed Sidebar ─────────────────
  Widget _buildSideMultiFeedPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Category Sub-Tabs
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.radar_rounded, color: Color(0xFF38BDF8), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Live City Directory',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _sidebarTab == 'complaints'
                            ? '${_complaints.length} Grievances'
                            : (_sidebarTab == 'stores'
                                ? '${_stores.length} Stores'
                                : '$_onlineRidersCount Online'),
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3-way Category Switcher
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _buildSidebarTabButton(
                        label: 'Grievances',
                        icon: Icons.campaign_rounded,
                        tabKey: 'complaints',
                        count: _complaints.length,
                      ),
                      _buildSidebarTabButton(
                        label: 'Stores',
                        icon: Icons.storefront_rounded,
                        tabKey: 'stores',
                        count: _stores.length,
                      ),
                      _buildSidebarTabButton(
                        label: 'Riders',
                        icon: Icons.two_wheeler_rounded,
                        tabKey: 'riders',
                        count: _riders.length,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Search Field
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: _sidebarTab == 'complaints'
                          ? 'Search complaint, ward, ID...'
                          : (_sidebarTab == 'stores'
                              ? 'Search store name, category...'
                              : 'Search rider name, phone, ID...'),
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),

                // Quick Filter Chips for Riders tab
                if (_sidebarTab == 'riders') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildRiderFilterChip('all', 'All (${_riders.length})'),
                      const SizedBox(width: 6),
                      _buildRiderFilterChip('online', '🟢 Online ($_onlineRidersCount)'),
                      const SizedBox(width: 6),
                      _buildRiderFilterChip('offline', '⚪ Offline ($_offlineRidersCount)'),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Feed List
          Expanded(child: _buildSidebarList()),
        ],
      ),
    );
  }

  Widget _buildSidebarTabButton({
    required String label,
    required IconData icon,
    required String tabKey,
    required int count,
  }) {
    final isSelected = _sidebarTab == tabKey;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _sidebarTab = tabKey;
            _searchQuery = '';
            _searchController.clear();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF94A3B8)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiderFilterChip(String key, String label) {
    final isSelected = _riderFilter == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _riderFilter = key),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarList() {
    if (_sidebarTab == 'complaints') {
      final list = _filteredComplaintsFeed;
      if (list.isEmpty) return _buildEmptyListMessage('No matching grievances found');

      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (ctx, idx) {
          final c = list[idx];
          final status = (c['status'] ?? 'Under Review').toString();
          final isResolved = status.toLowerCase() == 'resolved';
          final isInProgress = status.toLowerCase() == 'in progress';

          Color badgeColor = const Color(0xFFDC2626);
          if (isResolved) badgeColor = const Color(0xFF16A34A);
          if (isInProgress) badgeColor = const Color(0xFFD97706);

          final coords = _parseCoords(c['lat'], c['lng']);
          final hasCoords = coords != null;

          return InkWell(
            onTap: () => _zoomToEntity('complaint', c),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        c['complaintId'] ?? 'Incident',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const Spacer(),
                      if (hasCoords)
                        const Icon(Icons.pin_drop_rounded, size: 14, color: Color(0xFF0284C7))
                      else
                        const Icon(Icons.location_off_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c['category'] ?? 'General',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c['userAddress'] ?? 'No address provided',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (_sidebarTab == 'stores') {
      final list = _filteredStoresFeed;
      if (list.isEmpty) return _buildEmptyListMessage('No matching stores found');

      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (ctx, idx) {
          final s = list[idx];
          final loc = s['location'];
          final coords = _parseCoords(loc?['lat'], loc?['lng']);
          final hasCoords = coords != null;
          final status = (s['status'] ?? 'pending').toString();

          return InkWell(
            onTap: () => _zoomToEntity('store', s),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s['name'] ?? 'Store',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasCoords)
                        const Icon(Icons.pin_drop_rounded, size: 14, color: Color(0xFF0284C7))
                      else
                        const Icon(Icons.location_off_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Category: ${(s['category'] ?? 'General').toString().toUpperCase()} • Status: $status',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s['address'] ?? 'Address not specified',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // Default: Riders (Both Online and Offline)
    final list = _filteredRidersFeed;
    if (list.isEmpty) {
      return _buildEmptyListMessage(
        _riderFilter == 'online'
            ? 'No delivery riders currently online'
            : (_riderFilter == 'offline'
                ? 'No offline riders found'
                : 'No delivery riders found'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final r = list[idx];
        final coords = _parseCoords(
          r['latitude'] ?? r['lat'],
          r['longitude'] ?? r['lng'],
        );
        final hasCoords = coords != null;
        final isOnline = r['isOnline'] == true;
        final pinColor = isOnline ? const Color(0xFF0284C7) : const Color(0xFF64748B);

        return InkWell(
          onTap: hasCoords ? () => _zoomToEntity('rider', r) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: pinColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.two_wheeler_rounded, color: pinColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r['name'] ?? 'Express Rider',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                                  : const Color(0xFF64748B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isOnline ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isOnline ? 'ONLINE' : 'OFFLINE',
                                  style: TextStyle(
                                    color: isOnline ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isOnline
                            ? '📡 Live GPS • ${r['vehicleType'] ?? 'Motorcycle'}'
                            : (hasCoords
                                ? '🕒 Last Known GPS • ${r['vehicleType'] ?? 'Motorcycle'}'
                                : '⚠️ Location Pending • ${r['vehicleType'] ?? 'Motorcycle'}'),
                        style: TextStyle(
                          color: isOnline
                              ? const Color(0xFF0284C7)
                              : (hasCoords ? Colors.grey.shade700 : Colors.orange.shade800),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Phone: ${r['phone'] ?? 'N/A'} · ID: ${r['riderId'] ?? ''}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (hasCoords)
                  Tooltip(
                    message: isOnline ? 'Zoom to Live GPS' : 'Zoom to Last Known Location',
                    child: IconButton(
                      icon: Icon(Icons.pin_drop_rounded, size: 18, color: pinColor),
                      onPressed: () => _zoomToEntity('rider', r),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  )
                else
                  const Tooltip(
                    message: 'Location Pending',
                    child: Icon(Icons.location_off_rounded, size: 16, color: Colors.grey),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyListMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, color: Colors.grey, size: 36),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Widget: Selected Item Inspection Card (Bottom) ──────────────
  Widget _buildSelectedInspectionCard() {
    final type = _selectedEntity!['type'] as String;
    final data = _selectedEntity!['data'] as Map<String, dynamic>;

    if (type == 'complaint') {
      final status = (data['status'] ?? 'Under Review').toString();
      final isResolved = status.toLowerCase() == 'resolved';
      final isInProgress = status.toLowerCase() == 'in progress';
      Color statusColor = const Color(0xFFDC2626);
      if (isResolved) statusColor = const Color(0xFF16A34A);
      if (isInProgress) statusColor = const Color(0xFFD97706);

      final photoUrl = AdminApiService.normalizeImageUrl(data['imagePath']?.toString());

      return Card(
        color: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (photoUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    photoUrl,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 70,
                      height: 70,
                      color: const Color(0xFF1E293B),
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                )
              else
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.campaign_rounded, color: statusColor, size: 32),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          data['complaintId'] ?? 'Incident',
                          style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['category'] ?? 'General Civic Issue',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data['userAddress'] ?? 'Location not specified',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.visibility_rounded, size: 16),
                label: const Text('Manage & Resolve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => ComplaintDetailDialog(
                      complaint: data,
                      onActionCompleted: () => reload(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                tooltip: 'Dismiss',
                onPressed: () => setState(() => _selectedEntity = null),
              ),
            ],
          ),
        ),
      );
    }

    if (type == 'store') {
      return Card(
        color: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_rounded, color: Color(0xFF818CF8), size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data['name'] ?? 'Municipal Merchant',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Category: ${(data['category'] ?? 'General').toString().toUpperCase()} • Phone: ${data['phone'] ?? 'N/A'}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.info_outline_rounded, size: 16),
                label: const Text('Store Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => StoreDetailDialog(
                      store: data,
                      onActionCompleted: () => reload(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                tooltip: 'Dismiss',
                onPressed: () => setState(() => _selectedEntity = null),
              ),
            ],
          ),
        ),
      );
    }

    // Default for Rider
    final isOnline = data['isOnline'] == true;
    final rLat = (data['latitude'] ?? data['lat'] as num?)?.toDouble() ?? 0.0;
    final rLng = (data['longitude'] ?? data['lng'] as num?)?.toDouble() ?? 0.0;
    final hasLoc = rLat != 0.0 && rLng != 0.0;
    final pinColor = isOnline ? const Color(0xFF0284C7) : const Color(0xFF64748B);
    final statusColor = isOnline ? const Color(0xFF16A34A) : const Color(0xFF64748B);
    final lastSecs = data['lastSeenSecondsAgo'] as num?;

    return Card(
      color: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: pinColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.two_wheeler_rounded, color: isOnline ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isOnline ? 'ONLINE' : 'OFFLINE',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        data['name'] ?? 'Delivery Rider',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${data['riderId'] ?? ''})',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOnline
                        ? '📡 Live Tracking • GPS: ${hasLoc ? '${rLat.toStringAsFixed(5)}, ${rLng.toStringAsFixed(5)}' : 'Acquiring...'}'
                        : (hasLoc
                            ? '🕒 Last Known Location • GPS: ${rLat.toStringAsFixed(5)}, ${rLng.toStringAsFixed(5)}'
                            : '⚠️ Location Pending'),
                    style: TextStyle(
                      color: isOnline ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Vehicle: ${data['vehicleType'] ?? 'Motorcycle'} (${data['vehicleNumber'] ?? 'N/A'}) • Phone: ${data['phone'] ?? 'N/A'}'
                    '${lastSecs != null ? ' • Last seen: ${lastSecs < 60 ? '$lastSecs s ago' : '${(lastSecs / 60).round()} m ago'}' : ''}',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
              tooltip: 'Dismiss',
              onPressed: () => setState(() => _selectedEntity = null),
            ),
          ],
        ),
      ),
    );
  }
}
