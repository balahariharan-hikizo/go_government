import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';
import '../../widget/common_map.dart';
import '../../hive/hive_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../service/location_service.dart';
import 'address_book_screen.dart';

class SelectDeliveryLocationScreen extends StatefulWidget {
  final AddressModel? editAddress;

  const SelectDeliveryLocationScreen({
    super.key,
    this.editAddress,
  });

  @override
  State<SelectDeliveryLocationScreen> createState() => _SelectDeliveryLocationScreenState();
}

class _SelectDeliveryLocationScreenState extends State<SelectDeliveryLocationScreen> {
  final TextEditingController _houseController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final MapController _mapController = MapController();

  LatLng _currentMapCenter = LocationService.defaultLocation;
  String _addressText = LocationService.manualAddress ?? 'Select delivery address location';
  String _selectedType = 'Home'; // 'Home', 'Office', 'Others'
  bool _isKeyboardVisible = false;
  bool _isLoadingLocation = false;
  XFile? _landmarkImage;
  String? _existingImagePath;
  Timer? _mapDragDebounce;
  bool _isFromGps = false;

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    _currentMapCenter = camera.center;
    if (hasGesture) {
      _isFromGps = false;
      _mapDragDebounce?.cancel();
      _mapDragDebounce = Timer(const Duration(milliseconds: 500), () async {
        if (!mounted) return;
        setState(() => _isLoadingLocation = true);
        final details = await LocationService.getDetailedAddressFromCoordinates(
          camera.center.latitude,
          camera.center.longitude,
        );
        if (!mounted) return;
        setState(() {
          if (details['house'] != null &&
              details['house']!.isNotEmpty &&
              details['house'] != 'Flat 101') {
            _houseController.text = details['house']!;
          }
          _addressText = details['address'] ??
              '${camera.center.latitude.toStringAsFixed(4)}, ${camera.center.longitude.toStringAsFixed(4)}';
          _isLoadingLocation = false;
        });
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.editAddress != null) {
      final addr = widget.editAddress!;
      _selectedType = addr.type;
      _addressText = addr.description;
      if (addr.name != null && addr.name!.isNotEmpty) {
        _nameController.text = addr.name!;
      } else if (HiveService.userName.isNotEmpty) {
        _nameController.text = HiveService.userName;
      }
      if (addr.floor != null) {
        _floorController.text = addr.floor!;
      }
      _phoneController.text = addr.phone;
      _landmarkController.text = addr.landmark ?? '';
      _existingImagePath = addr.imagePath;
      if (addr.latitude != null && addr.longitude != null) {
        _currentMapCenter = LatLng(addr.latitude!, addr.longitude!);
      }
    } else {
      if (HiveService.userName.isNotEmpty) {
        _nameController.text = HiveService.userName;
      }
      if (HiveService.userPhone.isNotEmpty) {
        _phoneController.text = HiveService.userPhone;
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    final pos = await LocationService.getCurrentPosition(
      requestPermission: true,
      forceGps: true,
    );
    if (!mounted) return;
    if (pos != null) {
      _isFromGps = true;
      _currentMapCenter = LatLng(pos.latitude, pos.longitude);
      final details = await LocationService.getDetailedAddressFromCoordinates(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _houseController.text = details['house'] ?? '';
          _addressText = details['address'] ?? '';
          _isLoadingLocation = false;
        });
        _mapController.move(LatLng(pos.latitude, pos.longitude), 16.0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location & house details auto-filled from current GPS'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not access current location. Please enable GPS permissions.'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _pickLandmarkImage(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Responsive.w(20))),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.primary, size: Responsive.w(24)),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.of(bc).pop();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    setState(() {
                      _landmarkImage = image;
                      _existingImagePath = null;
                    });
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera, color: AppColors.primary, size: Responsive.w(24)),
                title: const Text('Take a Photo'),
                onTap: () async {
                  Navigator.of(bc).pop();
                  final XFile? image = await picker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    setState(() {
                      _landmarkImage = image;
                      _existingImagePath = null;
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _mapDragDebounce?.cancel();
    _houseController.dispose();
    _floorController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Detect keyboard visibility to toggle layouts statefully
    _isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    final bool isHouseValid = _houseController.text.trim().isNotEmpty;
    final bool isNameValid = _nameController.text.trim().isNotEmpty;
    final bool isPhoneValid = _phoneController.text.trim().isNotEmpty &&
        _phoneController.text.trim().length >= 10;
    final bool isFormValid = isHouseValid && isNameValid && isPhoneValid;

    return Scaffold(
      backgroundColor: AppColors.screenColor,
      body: CommonBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 1. Custom App Bar
              Container(
                height: Responsive.h(60),
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(20)),
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
                    CustomText.header(
                      'Select delivery location',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ],
                ),
              ),

              // 2. Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Map View portion (hide when keyboard is active to maximize input view space)
                      if (!_isKeyboardVisible) ...[
                        SizedBox(
                          height: Responsive.h(220),
                          width: double.infinity,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CommonMap(
                                  mapState: MapState.list,
                                  isWalkMode: false,
                                  center: _currentMapCenter,
                                  mapController: _mapController,
                                  onPositionChanged: _onMapPositionChanged,
                                ),
                              ),
                              // Floating Center Pin Marker
                              Center(
                                child: Container(
                                  margin: EdgeInsets.only(bottom: Responsive.h(30)),
                                  child: Icon(
                                    Icons.location_on,
                                    color: AppColors.primary,
                                    size: Responsive.w(38),
                                  ),
                                ),
                              ),
                              // "Use current location" overlay button
                              Positioned(
                                bottom: Responsive.h(12),
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: GestureDetector(
                                    onTap: _isLoadingLocation ? null : _useCurrentLocation,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: Responsive.w(16),
                                        vertical: Responsive.h(8),
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.white,
                                        borderRadius: BorderRadius.circular(Responsive.w(20)),
                                        border: Border.all(
                                          color: AppColors.primary,
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_isLoadingLocation) ...[
                                            SizedBox(
                                              width: Responsive.w(14),
                                              height: Responsive.w(14),
                                              child: const CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            SizedBox(width: Responsive.w(6)),
                                            CustomText.title(
                                              'Locating...',
                                              color: AppColors.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ] else ...[
                                            Icon(
                                              Icons.my_location,
                                              color: AppColors.primary,
                                              size: Responsive.w(14),
                                            ),
                                            SizedBox(width: Responsive.w(6)),
                                            CustomText.title(
                                              'Use current location',
                                              color: AppColors.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: Responsive.h(16)),
                      ],

                      // Address Form input inputs
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: Responsive.w(20)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header location detail
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: AppColors.primary,
                                  size: Responsive.w(18),
                                ),
                                SizedBox(width: Responsive.w(8)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CustomText.title(
                                        'User details',
                                        fontSize: 11,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      SizedBox(height: Responsive.h(2)),
                                      CustomText.title(
                                        _addressText,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        height: 1.35,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.h(16)),

                            // House / Flat / Building No. (Mandatory)
                            _buildInputBox(
                              controller: _houseController,
                              hint: 'House / Flat / Building No. *',
                              icon: Icons.home_work_outlined,
                              onChanged: (val) => setState(() {}),
                            ),
                            SizedBox(height: Responsive.h(12)),

                            // Floor / Level (Optional)
                            _buildInputBox(
                              controller: _floorController,
                              hint: 'Floor / Level (Optional, e.g. 2nd Floor)',
                              icon: Icons.layers_outlined,
                              onChanged: (val) => setState(() {}),
                            ),
                            SizedBox(height: Responsive.h(12)),

                            // Receiver Name* (Mandatory)
                            _buildInputBox(
                              controller: _nameController,
                              hint: 'Receiver Name *',
                              icon: Icons.person_outline,
                              onChanged: (val) => setState(() {}),
                            ),
                            SizedBox(height: Responsive.h(12)),

                            // Receiver Mobile Number* (Mandatory)
                            _buildInputBox(
                              controller: _phoneController,
                              hint: 'Mobile Number * (10 digits)',
                              icon: Icons.phone_android_outlined,
                              keyboardType: TextInputType.phone,
                              onChanged: (val) => setState(() {}),
                            ),
                            SizedBox(height: Responsive.h(16)),

                            // Save address as pills
                            CustomText.title(
                              'Save address as',
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                            SizedBox(height: Responsive.h(8)),
                            Row(
                              children: [
                                _buildTypePill('Home', Icons.home_outlined),
                                SizedBox(width: Responsive.w(10)),
                                _buildTypePill('Office', Icons.business_outlined),
                                SizedBox(width: Responsive.w(10)),
                                _buildTypePill('Others', Icons.place_outlined),
                              ],
                            ),
                            SizedBox(height: Responsive.h(16)),

                            // Door number / Landmark (Optional)
                            _buildInputBox(
                              controller: _landmarkController,
                              hint: 'Door number, Landmark (Optional)',
                            ),
                            SizedBox(height: Responsive.h(16)),

                            // Add an image / Preview container
                            if (_landmarkImage != null || (_existingImagePath != null && _existingImagePath!.isNotEmpty))
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(Responsive.w(10)),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(Responsive.w(12)),
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(Responsive.w(8)),
                                      child: _landmarkImage != null
                                          ? Image.file(
                                              File(_landmarkImage!.path),
                                              width: Responsive.w(44),
                                              height: Responsive.h(44),
                                              fit: BoxFit.cover,
                                            )
                                          : (_existingImagePath!.startsWith('assets/')
                                              ? Image.asset(
                                                  _existingImagePath!,
                                                  width: Responsive.w(44),
                                                  height: Responsive.h(44),
                                                  fit: BoxFit.cover,
                                                )
                                              : Image.file(
                                                  File(_existingImagePath!),
                                                  width: Responsive.w(44),
                                                  height: Responsive.h(44),
                                                  fit: BoxFit.cover,
                                                )),
                                    ),
                                    SizedBox(width: Responsive.w(12)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CustomText.title(
                                            'Landmark Photo Attached',
                                            color: AppColors.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          const Text(
                                            'Tap delete to remove or choose another',
                                            style: TextStyle(color: Colors.grey, fontSize: 8),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: AppColors.error, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _landmarkImage = null;
                                          _existingImagePath = null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: () => _pickLandmarkImage(context),
                                child: Container(
                                  width: double.infinity,
                                  height: Responsive.h(50),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(Responsive.w(12)),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.5),
                                      style: BorderStyle.solid,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo_outlined,
                                        color: AppColors.primary,
                                        size: Responsive.w(16),
                                      ),
                                      SizedBox(width: Responsive.w(8)),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CustomText.title(
                                            'Add an image',
                                            color: AppColors.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          const Text(
                                            'This helps our experts find your exact location faster',
                                            style: TextStyle(color: Colors.grey, fontSize: 8),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            SizedBox(height: Responsive.h(100)),
                          ],
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
      // Sticky Bottom Save Address CTA Button
      bottomNavigationBar: Container(
        color: AppColors.white,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(20),
          vertical: Responsive.h(16),
        ),
        child: GestureDetector(
          onTap: () async {
            if (_houseController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Please enter House / Flat / Building No.'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
                ),
              );
              return;
            }
            if (_nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Please enter Receiver Name'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
                ),
              );
              return;
            }
            if (_phoneController.text.trim().length < 10) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Please enter a valid 10-digit Mobile Number'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
                ),
              );
              return;
            }

            final List<String> addressParts = [];
            if (_houseController.text.trim().isNotEmpty) {
              addressParts.add(_houseController.text.trim());
            }
            if (_floorController.text.trim().isNotEmpty) {
              addressParts.add('Floor: ${_floorController.text.trim()}');
            }
            if (_addressText.trim().isNotEmpty &&
                _addressText != 'Select delivery address location') {
              addressParts.add(_addressText.trim());
            }

            final String fullDescription =
                addressParts.isNotEmpty ? addressParts.join(', ') : _addressText;

            final newAddr = AddressModel(
              id: widget.editAddress?.id,
              type: _selectedType,
              description: fullDescription,
              name: _nameController.text.trim(),
              floor: _floorController.text.trim(),
              phone: _phoneController.text.trim(),
              landmark: _landmarkController.text.trim(),
              imagePath: _landmarkImage?.path ?? _existingImagePath,
              isDefault: widget.editAddress?.isDefault ?? false,
              latitude: _currentMapCenter.latitude,
              longitude: _currentMapCenter.longitude,
            );

            final nav = Navigator.of(context);

            // If user explicitly chose live GPS, keep GPS mode active; otherwise persist chosen pin as manual location
            if (_isFromGps) {
              await HiveService.clearManualLocation();
            } else {
              await HiveService.setManualLocation(
                latitude: _currentMapCenter.latitude,
                longitude: _currentMapCenter.longitude,
                address: fullDescription,
              );
            }

            nav.pop(newAddr);
          },
          child: Container(
            height: Responsive.h(48),
            decoration: BoxDecoration(
              color: isFormValid ? AppColors.primary : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(Responsive.w(24)),
              border: Border.all(
                color: isFormValid ? AppColors.primary : Colors.grey.shade400,
                width: 1.2,
              ),
            ),
            child: Center(
              child: CustomText.title(
                'Save address',
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBox({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      height: Responsive.h(48),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(12)),
        border: Border.all(
          color: AppColors.outliner,
          width: 1.2,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (icon != null)
            Icon(
              icon,
              color: AppColors.primary,
              size: Responsive.w(18),
            ),
        ],
      ),
    );
  }

  Widget _buildTypePill(String type, IconData icon) {
    final bool isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(16),
          vertical: Responsive.h(8),
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF2EC) : AppColors.white,
          borderRadius: BorderRadius.circular(Responsive.w(16)),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey,
              size: Responsive.w(14),
            ),
            SizedBox(width: Responsive.w(6)),
            CustomText.title(
              type,
              color: isSelected ? AppColors.primary : Colors.grey.shade700,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ],
        ),
      ),
    );
  }
}
