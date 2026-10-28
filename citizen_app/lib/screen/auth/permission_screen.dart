import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_government/service/location_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../constants/route_constants.dart';
import '../../hive/hive_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/custom_text.dart';
import '../complaint/pick_location_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _isLocationGranted = false;
  bool _isCameraGranted = false;
  bool _isStorageGranted = false;
  String? _manualAddress;
  bool _isLoading = true;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentPermissions();
  }

  Future<void> _checkCurrentPermissions() async {
    final locationStatus = await Permission.location.status;
    if (locationStatus.isGranted) {
      await HiveService.setHasSeenPermissionScreen(true);
      if (!mounted) return;
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final isFirstTime = args?['isFirstTime'] ?? false;
      // If this screen was opened on restart (not first-time registration onboarding) and GPS is active,
      // redirect immediately to MainScreen so citizen never sees a permission screen with GPS already active!
      if (!isFirstTime && mounted) {
        Navigator.pushReplacementNamed(context, RouteConstants.main);
        return;
      }
    }

    final cameraStatus = await Permission.camera.status;

    bool storageGranted = false;
    if (Platform.isAndroid) {
      final photosStatus = await Permission.photos.status;
      final storageStatus = await Permission.storage.status;
      storageGranted = photosStatus.isGranted || storageStatus.isGranted;
    } else {
      final photosStatus = await Permission.photos.status;
      storageGranted = photosStatus.isGranted;
    }

    final manual = HiveService.getManualLocation();
    String? manualAddr;
    if (manual != null && manual['address'] != null) {
      manualAddr = manual['address'] as String;
    }

    if (!mounted) return;
    setState(() {
      _isLocationGranted = locationStatus.isGranted;
      _isCameraGranted = cameraStatus.isGranted;
      _isStorageGranted = storageGranted;
      _manualAddress = manualAddr;
      _isLoading = false;
    });
  }

  bool get _hasLocation => _isLocationGranted || (_manualAddress != null && _manualAddress!.trim().isNotEmpty);


  Future<void> _requestLocation() async {
    final status = await Permission.location.request();
    if (!mounted) return;
    setState(() {
      _isLocationGranted = status.isGranted;
    });
    if (status.isGranted) {
      final isGpsOn = await Geolocator.isLocationServiceEnabled();
      if (!isGpsOn) {
        await Geolocator.openLocationSettings();
      }
      await HiveService.setHasSeenPermissionScreen(true);
      await HiveService.clearManualLocation();
      await LocationService.switchToLiveGps();
      setState(() {
        _manualAddress = null;
      });
      final pos = await LocationService.getCurrentPosition(requestPermission: true, forceGps: true);
      if (pos != null && mounted) {
        final addr = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.gps_fixed, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('GPS Enabled: $addr', maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
    if (status.isPermanentlyDenied) {
      _showSettingsNotice('Location');
    }
  }

  Future<void> _pickManualLocation() async {
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => const PickLocationScreen(isLiveGps: false),
        ),
      );

      if (result != null) {
        if (result['isGps'] == true) {
          await HiveService.clearManualLocation();
          setState(() {
            _manualAddress = null;
            _isLocationGranted = true;
          });
          return;
        }

        if (result['address'] != null) {
          final LatLng latLng = result['latLng'] as LatLng;
          final String addr = result['address'] as String;

          await HiveService.setManualLocation(
            latitude: latLng.latitude,
            longitude: latLng.longitude,
            address: addr,
          );

          // Also create a default address in saved addresses if empty
          final existingAddresses = HiveService.getSavedAddresses();
          if (existingAddresses.isEmpty) {
            final newAddrMap = {
              'id': 'ADDR-${DateTime.now().millisecondsSinceEpoch}',
              'type': 'Home',
              'description': addr,
              'phone': HiveService.userPhone.isNotEmpty ? HiveService.userPhone : '9876543210',
              'name': HiveService.userName.isNotEmpty ? HiveService.userName : 'Citizen',
              'house': '',
              'floor': '',
              'isDefault': true,
            };
            await HiveService.saveAddresses([newAddrMap]);
            await HiveService.setSelectedAddressIndex(0);
          }

          if (!mounted) return;
          setState(() {
            _manualAddress = addr;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Manual location set to: $addr',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
            ),
          );
        }
      }
    } finally {
      _isNavigating = false;
    }
  }


  void _showSettingsNotice(String permissionName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$permissionName permission is permanently denied. Please enable it in App Settings.'),
        action: SnackBarAction(
          label: 'Settings',
          textColor: Colors.amber,
          onPressed: () => openAppSettings(),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
      ),
    );
  }

  void _showLocationRequiredBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalCtx) {
        return SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(20), vertical: Responsive.h(16)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(Responsive.w(24))),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              Container(
                width: Responsive.w(40),
                height: Responsive.h(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: Responsive.h(16)),
              Container(
                padding: EdgeInsets.all(Responsive.w(14)),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_off_rounded,
                  color: const Color(0xFFE65100),
                  size: Responsive.w(32),
                ),
              ),
              SizedBox(height: Responsive.h(14)),
              CustomText.header(
                'Location is Required',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Responsive.h(8)),
              CustomText.subtitle(
                'Go Government is a civic services app and needs a location to show municipal grievances, public toilets, bus stops, and local citizen services in your area.\n\nYou cannot skip location without setting it. Please enable GPS or select your area manually on the map.',
                fontSize: 13,
                color: AppColors.grayFont,
                textAlign: TextAlign.center,
                height: 1.4,
              ),
              SizedBox(height: Responsive.h(12)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(10)),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(Responsive.w(12)),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFFE65100)),
                    SizedBox(width: Responsive.w(8)),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 11, color: Color(0xFF4E342E), height: 1.35),
                          children: [
                            TextSpan(
                              text: 'Why enable GPS? ',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                            ),
                            TextSpan(
                              text:
                                  'Enabling Device GPS permanently bypasses this permission screen on future app restarts. If you choose manual location, this screen will appear again on app restart.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: Responsive.h(18)),
              SizedBox(
                width: double.infinity,
                height: Responsive.h(48),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Responsive.w(14)),
                    ),
                  ),
                  icon: const Icon(Icons.my_location, color: Colors.white, size: 18),
                  label: const Text(
                    'Enable Device GPS',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(modalCtx);
                    _requestLocation();
                  },
                ),
              ),
              SizedBox(height: Responsive.h(10)),
              SizedBox(
                width: double.infinity,
                height: Responsive.h(48),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Responsive.w(14)),
                    ),
                  ),
                  icon: Icon(Icons.map_outlined, color: AppColors.primary, size: 18),
                  label: Text(
                    'Set Location Manually on Map',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(modalCtx);
                    _pickManualLocation();
                  },
                ),
              ),
              SizedBox(height: Responsive.h(10)),
            ],
          ),
        ),
      ),
    );
  },
    );
  }

  Future<void> _proceedToMain() async {
    // If location is NOT satisfied (neither GPS nor manual), block and prompt
    if (!_hasLocation) {
      _showLocationRequiredBottomSheet();
      return;
    }

    // Mark hasSeenPermissionScreen as true once the citizen has satisfied location (either GPS or manual)
    // so on future app restarts, the citizen is taken directly to MainScreen without loop!
    if (_isLocationGranted) {
      await HiveService.setHasSeenPermissionScreen(true);
      await HiveService.clearManualLocation();
      await LocationService.switchToLiveGps();
    } else {
      await HiveService.setHasSeenPermissionScreen(true);
    }

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, RouteConstants.main, (route) => false);
    }
  }


  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    return Scaffold(
      backgroundColor: AppColors.screenColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Padding(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(20)),
                child: Column(
                  children: [
                    SizedBox(height: Responsive.h(24)),

                    // Header Badge & Illustration
                    Container(
                      width: Responsive.w(76),
                      height: Responsive.w(76),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.15),
                            const Color(0xFFFFB74D).withValues(alpha: 0.25),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.verified_user_rounded,
                          color: AppColors.primary,
                          size: Responsive.w(38),
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.h(16)),

                    // Title
                    CustomText.header(
                      'Enable Permissions',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: Responsive.h(8)),

                    // Subtitle
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(12)),
                      child: CustomText.subtitle(
                        'Location access is required to show civic amenities and services near you. Camera and media access will only be requested when you use them in the app.',
                        fontSize: 13,
                        color: AppColors.grayFont,
                        textAlign: TextAlign.center,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: Responsive.h(20)),

                    // List of Permission Cards
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildLocationPermissionCard(),
                          SizedBox(height: Responsive.h(16)),

                          // Section Header for In-App Features
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: Responsive.w(4)),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                                SizedBox(width: Responsive.w(6)),
                                Text(
                                  'IN-APP FEATURES (Requested when used)',
                                  style: TextStyle(
                                    fontSize: Responsive.sp(10.5),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: Responsive.h(8)),

                          _buildInAppFeatureCard(
                            icon: Icons.camera_alt_rounded,
                            iconColor: const Color(0xFF1565C0),
                            iconBg: const Color(0xFFE3F2FD),
                            title: 'Camera Access',
                            badgeText: 'Requested on Use',
                            badgeColor: const Color(0xFF1565C0),
                            description:
                                'Used only when taking live photos for civic grievance reports (e.g. potholes, garbage) or scanning QR codes. Permission is requested only when you use this feature.',
                            isGranted: _isCameraGranted,
                          ),
                          SizedBox(height: Responsive.h(12)),
                          _buildInAppFeatureCard(
                            icon: Icons.photo_library_rounded,
                            iconColor: const Color(0xFF2E7D32),
                            iconBg: const Color(0xFFE8F5E9),
                            title: 'Photos & Media',
                            badgeText: 'Requested on Use',
                            badgeColor: const Color(0xFF2E7D32),
                            description:
                                'Used only when attaching photos, utility bills, or municipal documents from your gallery. Permission is requested only when you choose to upload.',
                            isGranted: _isStorageGranted,
                          ),
                          SizedBox(height: Responsive.h(12)),
                        ],
                      ),
                    ),

                    // Bottom Action Area
                    Container(
                      padding: EdgeInsets.symmetric(vertical: Responsive.h(12)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Primary CTA
                          SizedBox(
                            width: double.infinity,
                            height: Responsive.h(50),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _hasLocation ? AppColors.primary : const Color(0xFFE65100),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(Responsive.w(16)),
                                ),
                              ),
                              onPressed: _hasLocation ? _proceedToMain : _requestLocation,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _hasLocation ? Icons.arrow_forward_rounded : Icons.my_location_rounded,
                                    color: Colors.white,
                                    size: Responsive.w(18),
                                  ),
                                  SizedBox(width: Responsive.w(8)),
                                  CustomText.title(
                                    _hasLocation ? 'Continue to App' : 'Enable Location to Continue',
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: Responsive.h(8)),

                          // Secondary action
                          if (!_hasLocation)
                            TextButton.icon(
                              onPressed: _pickManualLocation,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: Responsive.h(8)),
                              ),
                              icon: const Icon(Icons.map_outlined, size: 16, color: AppColors.primary),
                              label: CustomText.title(
                                'Or Set Location Manually on Map',
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else if (!_isLocationGranted) ...[
                            SizedBox(height: Responsive.h(2)),
                            Text(
                              'Using manual location • Permission screen will reappear on app restart',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFE65100),
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLocationPermissionCard() {
    final bool hasManual = _manualAddress != null && _manualAddress!.isNotEmpty;
    final bool isGpsActive = _isLocationGranted && !hasManual;
    final bool isLocationReady = isGpsActive || hasManual;

    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(18)),
        border: Border.all(
          color: isLocationReady ? Colors.green.withValues(alpha: 0.35) : const Color(0xFFE65100).withValues(alpha: 0.5),
          width: isLocationReady ? 1.2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isLocationReady ? Colors.black.withValues(alpha: 0.03) : const Color(0xFFE65100).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Container
              Container(
                width: Responsive.w(44),
                height: Responsive.w(44),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(Responsive.w(14)),
                ),
                child: Center(
                  child: Icon(Icons.location_on_rounded, color: const Color(0xFFE65100), size: Responsive.w(22)),
                ),
              ),
              SizedBox(width: Responsive.w(12)),

              // Title and Tag
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Responsive.w(6),
                      runSpacing: Responsive.h(4),
                      children: [
                        CustomText.title(
                          'Location Access',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(6),
                            vertical: Responsive.h(2),
                          ),
                          decoration: BoxDecoration(
                            color: isLocationReady
                                ? Colors.green.withValues(alpha: 0.1)
                                : const Color(0xFFE65100).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(Responsive.w(6)),
                          ),
                          child: Text(
                            isGpsActive
                                ? 'GPS Active'
                                : (hasManual ? 'Manual Location' : 'Mandatory *'),
                            style: TextStyle(
                              color: isLocationReady ? Colors.green : const Color(0xFFE65100),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(4)),
                    CustomText.subtitle(
                      isGpsActive
                          ? 'Device GPS is active and auto-tagging your civic area, nearby bus stops, and public amenities.'
                          : (hasManual
                              ? '📍 Location: $_manualAddress'
                              : 'Mandatory: Required to locate civic issues, nearest bus stops, toilets, and municipal facilities. Please enable GPS or select your area manually.'),
                      fontSize: 12,
                      color: hasManual ? const Color(0xFF2E7D32) : AppColors.grayFont,
                      height: 1.35,
                    ),
                  ],
                ),
              ),
              SizedBox(width: Responsive.w(8)),

              // Status Badge
              if (isLocationReady)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(10),
                    vertical: Responsive.h(6),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Responsive.w(12)),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 14),
                      SizedBox(width: Responsive.w(4)),
                      Text(
                        isGpsActive ? 'Allowed' : 'Set ✓',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          SizedBox(height: Responsive.h(12)),

          // Location Action Buttons Row
          Row(
            children: [
              // GPS Button
              Expanded(
                child: SizedBox(
                  height: Responsive.h(34),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isGpsActive ? Colors.grey.shade200 : AppColors.primary,
                      foregroundColor: isGpsActive ? AppColors.black : Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Responsive.w(10)),
                      ),
                    ),
                    onPressed: _requestLocation,
                    icon: Icon(
                      Icons.my_location,
                      size: Responsive.w(14),
                      color: isGpsActive ? AppColors.black : Colors.white,
                    ),
                    label: Text(
                      isGpsActive ? 'GPS Enabled' : 'Enable GPS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isGpsActive ? AppColors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: Responsive.w(8)),

              // Manual Location Button
              Expanded(
                child: SizedBox(
                  height: Responsive.h(34),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: hasManual ? Colors.green : AppColors.primary,
                        width: 1.2,
                      ),
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Responsive.w(10)),
                      ),
                    ),
                    onPressed: _pickManualLocation,
                    icon: Icon(
                      Icons.map_outlined,
                      size: Responsive.w(14),
                      color: hasManual ? Colors.green : AppColors.primary,
                    ),
                    label: Text(
                      hasManual ? 'Change on Map' : 'Set Manually',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: hasManual ? Colors.green : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(10)),

          // Restart Behavior Explanatory Notice
          Container(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(10), vertical: Responsive.h(8)),
            decoration: BoxDecoration(
              color: isGpsActive
                  ? const Color(0xFFE8F5E9)
                  : (hasManual ? const Color(0xFFFFF8E1) : const Color(0xFFF1F8E9)),
              borderRadius: BorderRadius.circular(Responsive.w(10)),
              border: Border.all(
                color: isGpsActive
                    ? const Color(0xFFA5D6A7)
                    : (hasManual ? const Color(0xFFFFD54F) : const Color(0xFFC8E6C9)),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isGpsActive
                      ? Icons.check_circle_outline
                      : (hasManual ? Icons.info_outline : Icons.lightbulb_outline),
                  size: 15,
                  color: isGpsActive
                      ? const Color(0xFF2E7D32)
                      : (hasManual ? const Color(0xFFE65100) : const Color(0xFF2E7D32)),
                ),
                SizedBox(width: Responsive.w(8)),
                Expanded(
                  child: Text(
                    isGpsActive
                        ? 'Device GPS is active! This permission screen will be skipped on future app restarts.'
                        : (hasManual
                            ? 'Manual location active: This screen will show again on app restart until Device GPS is enabled.'
                            : 'Tip: Enable Device GPS to bypass this screen on app restart. Manual location will prompt this screen again on restart.'),
                    style: TextStyle(
                      fontSize: 11,
                      color: isGpsActive
                          ? const Color(0xFF1B5E20)
                          : (hasManual ? const Color(0xFFE65100) : const Color(0xFF2E7D32)),
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInAppFeatureCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required String description,
    required bool isGranted,
  }) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(18)),
        border: Border.all(
          color: isGranted ? Colors.green.withValues(alpha: 0.35) : AppColors.outliner.withValues(alpha: 0.3),
          width: isGranted ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Container
              Container(
                width: Responsive.w(44),
                height: Responsive.w(44),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(Responsive.w(14)),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: Responsive.w(22)),
                ),
              ),
              SizedBox(width: Responsive.w(12)),

              // Title and Tag
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Responsive.w(6),
                      runSpacing: Responsive.h(4),
                      children: [
                        CustomText.title(
                          title,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(6),
                            vertical: Responsive.h(2),
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(Responsive.w(6)),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(4)),
                    CustomText.subtitle(
                      description,
                      fontSize: 12,
                      color: AppColors.grayFont,
                      height: 1.35,
                    ),
                  ],
                ),
              ),
              SizedBox(width: Responsive.w(8)),

              // Status indicator badge (No action button needed - requested in-app on demand)
              isGranted
                  ? Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.w(8),
                        vertical: Responsive.h(5),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(Responsive.w(12)),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 13),
                          SizedBox(width: Responsive.w(4)),
                          const Text(
                            'Allowed',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.w(8),
                        vertical: Responsive.h(5),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(Responsive.w(12)),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app_outlined, color: Colors.grey.shade600, size: 13),
                          SizedBox(width: Responsive.w(4)),
                          Text(
                            'On Use',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
