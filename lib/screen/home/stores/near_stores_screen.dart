import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../network/store_api_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/responsive_helper.dart';
import '../../../widget/common_background.dart';
import '../../../widget/custom_text.dart';
import '../../../widget/common_map.dart';
import '../../../widget/common_cart_badge.dart';
import '../../../constants/route_constants.dart';
import '../../../service/cart_manager.dart';
import '../../../service/location_service.dart';
import '../../../hive/hive_service.dart';
import '../../../network/api_client.dart';
import '../../../utils/call_launcher.dart';

class NearStoresScreen extends StatefulWidget {
  const NearStoresScreen({super.key});

  @override
  State<NearStoresScreen> createState() => _NearStoresScreenState();
}

class _NearStoresScreenState extends State<NearStoresScreen> {
  late final VoidCallback _cartListener;
  LatLng? _userPos;

  bool _isLoadingStores = true;
  late List<Map<String, dynamic>> _stores;

  @override
  void initState() {
    super.initState();
    if (LocationService.hasManualLocation) {
      final mPos = LocationService.getManualPosition();
      if (mPos != null) {
        _userPos = LatLng(mPos.latitude, mPos.longitude);
      } else {
        _userPos = LocationService.defaultLocation;
      }
    } else {
      _userPos = LocationService.defaultLocation;
    }
    _initStores();
    _loadRealStores();
    _cartListener = () {
      if (mounted) setState(() {});
    };
    CartManager.instance.cartItems.addListener(_cartListener);
    _detectLocation();
  }

  void _initStores() {
    _stores = [];
  }

  void _updateRealtimeDistances() {
    final basePos = _userPos ?? LocationService.defaultLocation;
    for (var store in _stores) {
      final lat = (store['lat'] as num?)?.toDouble() ?? basePos.latitude;
      final lng = (store['lng'] as num?)?.toDouble() ?? basePos.longitude;
      final dist = LocationService.calculateDistance(
        basePos.latitude,
        basePos.longitude,
        lat,
        lng,
      );
      store['distance'] = LocationService.formatDistance(dist);
    }
  }

  Future<void> _loadRealStores() async {
    if (mounted) setState(() => _isLoadingStores = true);
    final basePos = _userPos ?? LocationService.defaultLocation;

    // Fetch live approved stores from our GoGovernment database ONLY
    final approvedBackendStores = <Map<String, dynamic>>[];
    try {
      final list = await StoreApiService.fetchApprovedStores();
      for (final s in list) {
        // Skip offline stores - only online stores should be visible to citizens
        if (s['isOnline'] == false) continue;

          final lat = (s['location']?['lat'] as num?)?.toDouble() ?? (basePos.latitude + 0.001);
          final lng = (s['location']?['lng'] as num?)?.toDouble() ?? (basePos.longitude + 0.001);
          final dist = LocationService.calculateDistance(basePos.latitude, basePos.longitude, lat, lng);
          final category = (s['category'] ?? 'general').toString().toLowerCase();

          final bool isMedical = category == 'medical';
          final fallbackImg = isMedical ? 'assets/images/medical.png' : 'assets/images/vegstore.png';
          final rawImg = (s['storeImage'] ?? '').toString().trim();
          final storeImg = rawImg.isNotEmpty ? rawImg : fallbackImg;

          approvedBackendStores.add({
            'id': s['storeId'] ?? s['_id'] ?? 'STORE_${approvedBackendStores.length + 1}',
            'title': s['name'] ?? 'Approved Store',
            'address': s['address'] ?? '',
            'image': storeImg,
            'type': isMedical ? 'medical' : 'vegstore',
            'category': category,
            'lat': lat,
            'lng': lng,
            'distance': LocationService.formatDistance(dist),
            'isGovApproved': true,
            'isOnline': s['isOnline'] ?? true,
            'phone': (s['phone'] ?? '').toString(),
            'ownerName': (s['ownerName'] ?? '').toString(),
          });
        }
      } catch (e) {
      debugPrint('[NearStores] Backend approved stores fetch error: $e');
    }

    if (!mounted) return;
    setState(() {
      _stores = approvedBackendStores;
      _isLoadingStores = false;
    });
  }

  Future<void> _detectLocation() async {
    if (LocationService.hasManualLocation) return;
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
        _updateRealtimeDistances();
      });
      if (shifted) {
        _loadRealStores();
      }
    }
  }

  @override
  void dispose() {
    CartManager.instance.cartItems.removeListener(_cartListener);
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
              // 1. Map Canvas
              Positioned.fill(
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: Responsive.h(280),
                      child: CommonMap(
                        mapState: MapState.list,
                        isWalkMode: false,
                        center: _userPos,
                        userLocationOverride: LocationService.hasManualLocation ? _userPos : null,
                        markers: _stores.map((store) {
                          final isMedical = store['type'] == 'medical';
                          return Marker(
                            point: LatLng(store['lat'] as double, store['lng'] as double),
                            width: 38,
                            height: 38,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).pushNamed(
                                  RouteConstants.storeDetails,
                                  arguments: {
                                    'storeId': store['id'],
                                    'storeName': store['title'],
                                    'storeAddress': store['address'],
                                    'storeImage': store['image'],
                                    'storeType': store['type'],
                                    'storePhone': store['phone'] ?? '',
                                    'ownerName': store['ownerName'] ?? '',
                                  },
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isMedical ? const Color(0xFFE53935) : const Color(0xFF4CAF50),
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: Icon(
                                  isMedical ? Icons.local_pharmacy : Icons.eco,
                                  color: isMedical ? const Color(0xFFE53935) : const Color(0xFF4CAF50),
                                  size: 18,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              // 2. Top Header with Back Button and Location Picker Badge
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
                              Navigator.pop(context);
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
                          Expanded(
                            child: CustomText.header(
                              'Near Stores',
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
                    SizedBox(width: Responsive.w(8)),
                    _buildLocationPickerBadge(),
                  ],
                ),
              ),

              // 3. Scrollable List of Stores
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                top: Responsive.h(290),
                child: _isLoadingStores
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : _stores.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: Responsive.w(30)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.store_mall_directory_outlined,
                                    size: Responsive.w(56),
                                    color: Colors.grey.shade400,
                                  ),
                                  SizedBox(height: Responsive.h(12)),
                                  CustomText.title(
                                    'No Stores Available',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                  SizedBox(height: Responsive.h(6)),
                                  CustomText.body(
                                    'There are no approved government stores in this area yet.',
                                    fontSize: 12,
                                    color: AppColors.grayFont,
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: Responsive.h(16)),
                                  ElevatedButton.icon(
                                    onPressed: _loadRealStores,
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('Refresh'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(Responsive.w(20)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.w(20),
                              vertical: Responsive.h(12),
                            ),
                            itemCount: _stores.length,
                            itemBuilder: (context, index) {
                              final store = _stores[index];
                              return Padding(
                                padding: EdgeInsets.only(bottom: Responsive.h(16)),
                                child: _buildStoreCard(store),
                              );
                            },
                          ),
              ),

              Positioned(
                bottom: Responsive.h(20),
                right: Responsive.w(20),
                child: CommonCartBadge(
                  itemCount: CartManager.instance.totalCartCount,
                  onTap: () {
                    String storeType = 'vegstore';
                    if (CartManager.instance.cartItems.value.isNotEmpty) {
                      final firstId =
                          CartManager.instance.cartItems.value.keys.first;
                      if (firstId.startsWith('m')) {
                        storeType = 'medical';
                      }
                    }
                    Navigator.of(context).pushNamed(
                      RouteConstants.cart,
                      arguments: storeType,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorefrontImage(String? imagePath, String? type) {
    final fallbackAsset = type == 'medical'
        ? 'assets/images/medical.png'
        : 'assets/images/vegstore.png';

    if (imagePath == null || imagePath.isEmpty) {
      return Image.asset(
        fallbackAsset,
        width: double.infinity,
        height: Responsive.h(120),
        fit: BoxFit.cover,
      );
    }

    final normalized = ApiClient.normalizeImageUrl(imagePath);
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return Image.network(
        normalized,
        width: double.infinity,
        height: Responsive.h(120),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          fallbackAsset,
          width: double.infinity,
          height: Responsive.h(120),
          fit: BoxFit.cover,
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: double.infinity,
            height: Responsive.h(120),
            color: Colors.grey.shade100,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          );
        },
      );
    }

    return Image.asset(
      imagePath,
      width: double.infinity,
      height: Responsive.h(120),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        fallbackAsset,
        width: double.infinity,
        height: Responsive.h(120),
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store) {
    final rawPhone = (store['phone'] ?? '').toString().trim();
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          RouteConstants.storeDetails,
          arguments: {
            'storeId': store['id'],
            'storeName': store['title'],
            'storeAddress': store['address'],
            'storeImage': store['image'],
            'storeType': store['type'],
            'storePhone': rawPhone,
            'ownerName': store['ownerName'] ?? '',
          },
        );
      },
      child: Container(
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
            // Store Title, Call Icon & Distance Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: CustomText.title(
                          store['title'],
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (rawPhone.isNotEmpty) ...[
                        SizedBox(width: Responsive.w(8)),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              debugPrint('[NearStores] Tapped call for ${store['title']} -> $rawPhone');
                              CallLauncher.launchCall(
                                context,
                                phone: rawPhone,
                                name: store['title'],
                              );
                            },
                            borderRadius: BorderRadius.circular(Responsive.w(20)),
                            child: Padding(
                              padding: EdgeInsets.all(Responsive.w(4)),
                              child: Container(
                                width: Responsive.w(34),
                                height: Responsive.w(34),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.green.shade400, width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withValues(alpha: 0.15),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.phone,
                                  size: 16,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (store['distance'] != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(8),
                      vertical: Responsive.h(2),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(Responsive.w(10)),
                    ),
                    child: Text(
                      store['distance'],
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: Responsive.h(4)),

            // Address Subtitle
            CustomText.subtitle(
              store['address'],
              fontSize: 11,
              color: AppColors.grayFont,
              maxLines: 2,
            ),
            SizedBox(height: Responsive.h(12)),

            // Storefront Banner image with floating action cart bag button
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Responsive.w(12)),
                  child: _buildStorefrontImage(store['image'], store['type']),
                ),
                if (store['hasCart'] == true)
                  Positioned(
                    right: Responsive.w(12),
                    bottom: -Responsive.h(10),
                    child: Container(
                      width: Responsive.w(36),
                      height: Responsive.w(36),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(Responsive.w(12)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(
                          color: AppColors.primary,
                          width: Responsive.w(1.2),
                        ),
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.primary,
                        size: Responsive.w(18),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
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
                'Change Store Location',
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
                subtitle: const Text('Find stores near your live device coordinates', style: TextStyle(fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final pos = await LocationService.switchToLiveGps();
                  if (pos != null && mounted) {
                    setState(() {
                      _userPos = LatLng(pos.latitude, pos.longitude);
                      _updateRealtimeDistances();
                    });
                    _loadRealStores();
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
                        _loadRealStores();
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
                          _updateRealtimeDistances();
                        });
                        _loadRealStores();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Updated stores location to: $addr'),
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
