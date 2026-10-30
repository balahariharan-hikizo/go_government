import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';
import '../../widget/common_map.dart';
import '../../service/location_service.dart';
import '../../constants/route_constants.dart';
import '../../bloc/complaint/complaint_bloc.dart';
import '../../bloc/complaint/complaint_event.dart';
import '../../bloc/complaint/complaint_state.dart';
import '../../bloc/report/report_bloc.dart';
import '../../bloc/report/report_event.dart';
import '../../bloc/transaction/transaction_bloc.dart';
import '../../bloc/transaction/transaction_event.dart';
import '../../widget/image_preview_dialog.dart';
import '../../services/translation_service.dart';

class AddComplaintScreen extends StatefulWidget {
  final String? category;

  const AddComplaintScreen({super.key, this.category});

  @override
  State<AddComplaintScreen> createState() => _AddComplaintScreenState();
}

class _AddComplaintScreenState extends State<AddComplaintScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  LatLng? _currentLatLng;
  String _currentAddress = 'Detecting current GPS location...';
  bool _isDetectingLocation = false;
  bool _isCustomLocation = false;
  bool _isNavigating = false;

  final List<String> _categories = [
    'Roads & Transportation',
    'Garbage & Waste Management',
    'Streetlights & Electricity',
    'Water Supply',
    'Drainage & Sewage',
    'Cleanliness & Sanitation',
    'Parks & Public Spaces',
    'Environmental Issues',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      context.read<ComplaintBloc>().add(
        SelectComplaintCategoryEvent(widget.category!),
      );
    }
    _descriptionController.addListener(_updateState);
    _detectLocation();
  }

  Future<void> _detectLocation({bool forceGps = false}) async {
    if (!mounted) return;

    if (forceGps) {
      await _resetToGps();
      return;
    }

    if (LocationService.hasManualLocation) {
      final mPos = LocationService.getManualPosition();
      setState(() {
        _currentLatLng = mPos != null
            ? LatLng(mPos.latitude, mPos.longitude)
            : LocationService.defaultLocation;
        _currentAddress = LocationService.manualAddress ?? 'Custom Selected Location';
        _isCustomLocation = true;
        _isDetectingLocation = false;
      });
      return;
    }

    setState(() => _isDetectingLocation = true);
    final pos = await LocationService.getCurrentPosition(
      requestPermission: true,
    );
    if (!mounted) return;
    if (pos != null) {
      final latLng = LatLng(pos.latitude, pos.longitude);
      final addr = await LocationService.getAddressFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (mounted) {
        setState(() {
          _currentLatLng = latLng;
          _currentAddress = addr;
          _isCustomLocation = false;
          _isDetectingLocation = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _currentLatLng = LocationService.defaultLocation;
          _currentAddress = 'Location not detected (Tap to retry)';
          _isDetectingLocation = false;
        });
      }
    }
  }

  Future<void> _resetToGps() async {
    if (!mounted) return;
    setState(() => _isDetectingLocation = true);

    final pos = await LocationService.switchToLiveGps();
    if (!mounted) return;

    if (pos != null) {
      final latLng = LatLng(pos.latitude, pos.longitude);
      final addr = await LocationService.getAddressFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (mounted) {
        setState(() {
          _currentLatLng = latLng;
          _currentAddress = addr;
          _isCustomLocation = false;
          _isDetectingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Switched to live GPS location'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  Future<void> _openLocationPicker() async {
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      final result = await Navigator.pushNamed(
        context,
        RouteConstants.pickLocation,
        arguments: {
          'initialLatLng': _currentLatLng,
          'initialAddress': _currentAddress,
        },
      );

      if (result is Map<String, dynamic> && mounted) {
        setState(() {
          _currentLatLng = result['latLng'] as LatLng;
          _currentAddress = result['address'] as String;
          _isCustomLocation = true;
        });
      }
    } finally {
      _isNavigating = false;
    }
  }

  Future<void> _onMiniMapTapped(LatLng point) async {
    setState(() {
      _currentLatLng = point;
      _isCustomLocation = true;
      _isDetectingLocation = true;
    });
    final addr = await LocationService.getAddressFromCoordinates(
      point.latitude,
      point.longitude,
    );
    if (!mounted) return;
    setState(() {
      _currentAddress = addr;
      _isDetectingLocation = false;
    });
  }

  void _editAddressManually() {
    final controller = TextEditingController(text: _currentAddress);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.edit_location_alt,
              color: AppColors.primary,
              size: Responsive.w(22),
            ),
            SizedBox(width: Responsive.w(8)),
            const Text(
              'Edit Location Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomText.body(
              'Add specific landmark, building, street, or gate to help the inspection team locate it quickly:',
              fontSize: 12,
              color: Colors.black54,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: TranslationService.translateSync(
                    'e.g. Near Pillar 45, Opposite City Hospital, Main Gate'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: CustomText.body('Cancel', color: Colors.grey),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final newAddr = controller.text.trim();
              if (newAddr.isNotEmpty) {
                setState(() {
                  _currentAddress = newAddr;
                  _isCustomLocation = true;
                });
              }
              Navigator.pop(ctx);
            },
            child: CustomText.title(
              'Save Address',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_updateState);
    _descriptionController.dispose();
    super.dispose();
  }

  void _updateState() {
    setState(() {});
  }

  Future<void> _pickImage(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Responsive.w(20)),
        ),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: AppColors.primary,
                  size: Responsive.w(24),
                ),
                title: CustomText.body('Photo Library'),
                onTap: () async {
                  Navigator.of(bc).pop();
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 1024,
                    maxHeight: 1024,
                    imageQuality: 75,
                  );
                  if (image != null) {
                    if (!context.mounted) return;
                    context.read<ComplaintBloc>().add(
                      PickComplaintImageEvent(image),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_camera,
                  color: AppColors.primary,
                  size: Responsive.w(24),
                ),
                title: CustomText.body('Camera'),
                onTap: () async {
                  Navigator.of(bc).pop();
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 1024,
                    maxHeight: 1024,
                    imageQuality: 75,
                  );
                  if (image != null) {
                    if (!context.mounted) return;
                    context.read<ComplaintBloc>().add(
                      PickComplaintImageEvent(image),
                    );
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: Responsive.w(70),
        leading: Padding(
          padding: EdgeInsets.only(left: Responsive.w(20)),
          child: Center(
            child: GestureDetector(
              onTap: () {
                context.read<ComplaintBloc>().add(ClearComplaintEvent());
                Navigator.pop(context);
              },
              child: Container(
                width: Responsive.w(40),
                height: Responsive.w(40),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(Responsive.w(12)),
                  border: Border.all(
                    color: AppColors.outliner,
                    width: Responsive.w(1.2),
                  ),
                ),
                child: Icon(
                  Icons.chevron_left,
                  color: AppColors.black,
                  size: Responsive.w(24),
                ),
              ),
            ),
          ),
        ),
        title: CustomText.header(
          widget.category ?? 'Add Complaint',
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: false,
      ),
      body: BlocConsumer<ComplaintBloc, ComplaintState>(
        listener: (context, state) {
          if (state.isSubmitted) {
            context.read<ReportBloc>().add(LoadReportsEvent());

            // Reward citizen coins for reporting complaint
            final rewardTx = {
              'id':
                  'REW-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
              'title': 'Complaint coins',
              'subtitle':
                  'Earned through reporting · ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
              'amount': '+200 Coins',
              'isPositive': true,
              'status': 'Credited',
              'date': 'Today',
              'items': [],
              'address': 'Grievance Redressal Reward',
              'listingPrice': '₹0.00',
              'sellingPrice': '+200 Coins',
              'grandTotal': '+200 Coins',
              'paid': '+200 Coins',
              'category': 'civic_reward',
              'paymentMethod': 'Reward Coins',
            };
            context.read<TransactionBloc>().add(AddCoinsEvent(200, reason: 'Complaint coins'));
            context.read<TransactionBloc>().add(AddTransactionEvent(rewardTx));

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Complaint Submitted & 200 Coins Earned!'),
                backgroundColor: AppColors.success,
              ),
            );
            context.read<ComplaintBloc>().add(ClearComplaintEvent());
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
          final String selectedCategory = state.selectedCategory.isNotEmpty
              ? state.selectedCategory
              : (widget.category ?? '');
          final XFile? imageFile = state.imageFile;
          final bool isSubmitting = state.isSubmitting;

          final bool isFormValid =
              selectedCategory.isNotEmpty &&
              _descriptionController.text.trim().isNotEmpty &&
              !isSubmitting;

          return CommonBackground(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(20),
                    vertical: Responsive.h(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Map container with full interactive selection
                      Container(
                        height: Responsive.h(190),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(Responsive.w(24)),
                          border: Border.all(
                            color: AppColors.outliner,
                            width: Responsive.w(1.5),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CommonMap(
                                center:
                                    _currentLatLng ??
                                    LocationService.defaultLocation,
                                zoom: 16.0,
                                showUserLocation: true,
                                userLocationOverride:
                                    _isCustomLocation ? _currentLatLng : null,
                                interactive: true,
                                showControls: false,
                                onTap: _onMiniMapTapped,
                                markers: _currentLatLng != null
                                    ? [
                                        Marker(
                                          point: _currentLatLng!,
                                          width: 42,
                                          height: 42,
                                          alignment: Alignment.topCenter,
                                          child: const Icon(
                                            Icons.location_on,
                                            color: AppColors.primary,
                                            size: 38,
                                          ),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            // Top Banner Hint
                            Positioned(
                              top: Responsive.h(10),
                              left: Responsive.w(12),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: Responsive.w(10),
                                  vertical: Responsive.h(4),
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(
                                    Responsive.w(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.touch_app,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    SizedBox(width: Responsive.w(4)),
                                    CustomText.body(
                                      'Tap map to set location',
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Top-right Expand / Pick on Map Button
                            Positioned(
                              top: Responsive.h(10),
                              right: Responsive.w(12),
                              child: GestureDetector(
                                onTap: _openLocationPicker,
                                child: Container(
                                  width: Responsive.w(36),
                                  height: Responsive.w(36),
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.15,
                                        ),
                                        blurRadius: Responsive.w(6),
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.open_in_full,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                            // Bottom-right My GPS Button
                            Positioned(
                              bottom: Responsive.h(10),
                              right: Responsive.w(12),
                              child: GestureDetector(
                                onTap: _resetToGps,
                                child: Container(
                                  width: Responsive.w(36),
                                  height: Responsive.w(36),
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.15,
                                        ),
                                        blurRadius: Responsive.w(6),
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: _isDetectingLocation
                                      ? Center(
                                          child: SizedBox(
                                            width: Responsive.w(14),
                                            height: Responsive.w(14),
                                            child:
                                                const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppColors.primary,
                                                ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.my_location,
                                          color: AppColors.primary,
                                          size: 18,
                                        ),
                                ),
                              ),
                            ),
                         
                         
                          ],
                        ),
                      ),
                      SizedBox(height: Responsive.h(16)),

                      // 2. Complaint Location Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: CustomText.subtitle(
                                    'Complaint Location',
                                    fontSize: 13,
                                    color: AppColors.grayFont,
                                    fontWeight: FontWeight.bold,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: Responsive.w(6)),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.w(6),
                                    vertical: Responsive.h(2),
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isCustomLocation
                                        ? const Color(0xFFFFF3E0)
                                        : const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(
                                      Responsive.w(8),
                                    ),
                                  ),
                                  child: Text(
                                    _isCustomLocation ? '📍 Custom' : '📡 GPS',
                                    style: TextStyle(
                                      color: _isCustomLocation
                                          ? const Color(0xFFE65100)
                                          : const Color(0xFF2E7D32),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: Responsive.w(8)),
                          GestureDetector(
                            onTap: _openLocationPicker,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  size: Responsive.w(13),
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: Responsive.w(3)),
                                CustomText.title(
                                  'Choose on Map',
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: Responsive.h(8)),

                      // Location Card with Edit Button
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(Responsive.w(14)),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(Responsive.w(16)),
                          border: Border.all(
                            color: AppColors.outliner,
                            width: Responsive.w(1.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: Responsive.h(2),
                                  ),
                                  child: Icon(
                                    Icons.location_on,
                                    color: AppColors.primary,
                                    size: Responsive.w(18),
                                  ),
                                ),
                                SizedBox(width: Responsive.w(10)),
                                Expanded(
                                  child: _isDetectingLocation
                                      ? Row(
                                          children: [
                                            SizedBox(
                                              width: Responsive.w(14),
                                              height: Responsive.w(14),
                                              child:
                                                  const CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AppColors.primary,
                                                  ),
                                            ),
                                            SizedBox(width: Responsive.w(10)),
                                            CustomText.body(
                                              'Detecting address...',
                                              fontSize: 13,
                                              color: Colors.grey,
                                            ),
                                          ],
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            CustomText.body(
                                              _currentAddress,
                                              fontSize: 13,
                                              color: const Color(0xFF333333),
                                              fontWeight: FontWeight.w500,
                                              height: 1.35,
                                            ),
                                            if (_currentLatLng != null)
                                              Padding(
                                                padding: EdgeInsets.only(
                                                  top: Responsive.h(4),
                                                ),
                                                child: Text(
                                                  'Coordinates: ${_currentLatLng!.latitude.toStringAsFixed(4)}, ${_currentLatLng!.longitude.toStringAsFixed(4)}',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                ),
                                SizedBox(width: Responsive.w(8)),
                                // Edit landmark details icon
                                GestureDetector(
                                  onTap: _editAddressManually,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.edit_outlined,
                                      size: Responsive.w(16),
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_isCustomLocation) ...[
                              SizedBox(height: Responsive.h(10)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  GestureDetector(
                                    onTap: _resetToGps,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: Responsive.w(8),
                                        vertical: Responsive.h(4),
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0F4F8),
                                        borderRadius: BorderRadius.circular(
                                          Responsive.w(8),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.my_location,
                                            size: Responsive.w(12),
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: Responsive.w(4)),
                                          CustomText.body(
                                            'Reset to Current GPS',
                                            fontSize: 10,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: Responsive.h(20)),

                      // 3. Add Category Section (Only if not preselected)
                      if (widget.category == null) ...[
                        CustomText.subtitle(
                          'Add Category',
                          fontSize: 13,
                          color: AppColors.grayFont,
                          fontWeight: FontWeight.bold,
                        ),
                        SizedBox(height: Responsive.h(8)),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(
                              Responsive.w(16),
                            ),
                            border: Border.all(
                              color: AppColors.outliner,
                              width: Responsive.w(1.5),
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(16),
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedCategory.isNotEmpty
                                ? selectedCategory
                                : null,
                            hint: CustomText.body(
                              'Select Category',
                              color: Colors.grey,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            items: _categories.map((String cat) {
                              return DropdownMenuItem<String>(
                                value: cat,
                                child: CustomText.body(cat),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                context.read<ComplaintBloc>().add(
                                  SelectComplaintCategoryEvent(value),
                                );
                              }
                            },
                          ),
                        ),
                        SizedBox(height: Responsive.h(20)),
                      ],

                      // 4. Description section
                      CustomText.subtitle(
                        'Please provide a brief description about the complaint',
                        fontSize: 13,
                        color: AppColors.grayFont,
                        fontWeight: FontWeight.bold,
                      ),
                      SizedBox(height: Responsive.h(8)),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 4,
                        style: TextStyle(
                          fontSize: Responsive.sp(14),
                          color: AppColors.black,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.white,
                          hintText: TranslationService.translateSync('Enter details about the issue...'),
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: Responsive.sp(14),
                          ),
                          contentPadding: EdgeInsets.all(Responsive.w(16)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              Responsive.w(16),
                            ),
                            borderSide: BorderSide(
                              color: AppColors.outliner,
                              width: Responsive.w(1.5),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              Responsive.w(16),
                            ),
                            borderSide: BorderSide(
                              color: AppColors.outliner,
                              width: Responsive.w(1.5),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              Responsive.w(16),
                            ),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: Responsive.w(1.5),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: Responsive.h(20)),

                      // 5. Add a photo section
                      CustomText.subtitle(
                        'Add a photo',
                        fontSize: 13,
                        color: AppColors.grayFont,
                        fontWeight: FontWeight.bold,
                      ),
                      SizedBox(height: Responsive.h(8)),
                      GestureDetector(
                        onTap: () {
                          if (imageFile != null) {
                            ImagePreviewDialog.show(
                              context,
                              file: File(imageFile.path),
                              title: selectedCategory.isNotEmpty
                                  ? selectedCategory
                                  : 'Complaint Photo Evidence',
                              subtitle: _currentAddress.isNotEmpty
                                  ? _currentAddress
                                  : 'Tap image to zoom or pan',
                            );
                          } else {
                            _pickImage(context);
                          }
                        },
                        child: Container(
                          height: imageFile != null ? Responsive.h(170) : Responsive.h(120),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: imageFile != null ? const Color(0xFF0F172A) : AppColors.white,
                            borderRadius: BorderRadius.circular(
                              Responsive.w(16),
                            ),
                            border: Border.all(
                              color: imageFile != null ? Colors.transparent : AppColors.outliner,
                              width: Responsive.w(1.5),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: imageFile != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: Responsive.h(10),
                                          horizontal: Responsive.w(12),
                                        ),
                                        child: Image.file(
                                          File(imageFile.path),
                                          fit: BoxFit.contain,
                                          gaplessPlayback: true,
                                        ),
                                      ),
                                    ),
                                    // Top right remove button
                                    Positioned(
                                      top: Responsive.h(8),
                                      right: Responsive.w(8),
                                      child: GestureDetector(
                                        onTap: () {
                                          context.read<ComplaintBloc>().add(
                                            ClearComplaintEvent(),
                                          );
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(
                                            Responsive.w(6),
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.65),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: Responsive.w(16),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Bottom right tap to preview badge
                                    Positioned(
                                      bottom: Responsive.h(8),
                                      right: Responsive.w(8),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: Responsive.w(8),
                                          vertical: Responsive.h(4),
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(Responsive.w(12)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.zoom_in, color: Colors.white, size: Responsive.w(14)),
                                            SizedBox(width: Responsive.w(4)),
                                            CustomText.body(
                                              'Preview',
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Bottom left change photo button
                                    Positioned(
                                      bottom: Responsive.h(8),
                                      left: Responsive.w(8),
                                      child: GestureDetector(
                                        onTap: () => _pickImage(context),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: Responsive.w(10),
                                            vertical: Responsive.h(5),
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(Responsive.w(12)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.edit, color: Colors.white, size: Responsive.w(13)),
                                              SizedBox(width: Responsive.w(4)),
                                              CustomText.body(
                                                'Change',
                                                color: Colors.white,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Center(
                                  child: Container(
                                    width: Responsive.w(44),
                                    height: Responsive.w(44),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFBF8F6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.add_a_photo_outlined,
                                      color: AppColors.black,
                                      size: Responsive.w(20),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: Responsive.h(16)),

                      // 6. Disclaimer
                      Center(
                        child: CustomText.subtitle(
                          'Add a description and photo to submit your complaint',
                          fontSize: 11,
                          color: AppColors.grayFont,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: Responsive.h(12)),

                      // 7. Submit button
                      GestureDetector(
                        onTap: isFormValid
                            ? () {
                                final categoryToSubmit =
                                    selectedCategory.isNotEmpty
                                    ? selectedCategory
                                    : (widget.category ??
                                          'Roads & Transportation');
                                context.read<ComplaintBloc>().add(
                                  SubmitComplaintEvent(
                                    description: _descriptionController.text
                                        .trim(),
                                    category: categoryToSubmit,
                                    location: _currentAddress,
                                    imagePath: imageFile?.path,
                                    lat: _currentLatLng?.latitude,
                                    lng: _currentLatLng?.longitude,
                                  ),
                                );
                              }
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: Responsive.h(52),
                          decoration: BoxDecoration(
                            color: isFormValid
                                ? const Color(0xFFFFF6F3)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(
                              Responsive.w(26),
                            ),
                            border: Border.all(
                              color: isFormValid
                                  ? AppColors.primary
                                  : Colors.grey[300]!,
                              width: Responsive.w(1.5),
                            ),
                          ),
                          child: Center(
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                    ),
                                  )
                                : CustomText.title(
                                    'Submit',
                                    color: isFormValid
                                        ? AppColors.primary
                                        : Colors.grey[400]!,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                          ),
                        ),
                      ),
                      SizedBox(height: Responsive.h(40)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Custom Painter to render a stylized, high-fidelity local map
class MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Draw light gray block representing building blocks
    final paintBlock = Paint()
      ..color = const Color(0xFFFBF8F6)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.05, h * 0.05, w * 0.38, h * 0.38),
        const Radius.circular(12),
      ),
      paintBlock,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.55, h * 0.05, w * 0.4, h * 0.28),
        const Radius.circular(12),
      ),
      paintBlock,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.05, h * 0.55, w * 0.42, h * 0.4),
        const Radius.circular(12),
      ),
      paintBlock,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.58, h * 0.45, w * 0.37, h * 0.5),
        const Radius.circular(12),
      ),
      paintBlock,
    );

    // Draw white background roads
    final paintRoad = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16.0
      ..strokeCap = StrokeCap.round;

    // Vertical road
    canvas.drawLine(Offset(w * 0.5, -10), Offset(w * 0.5, h + 10), paintRoad);
    // Horizontal road
    canvas.drawLine(Offset(-10, h * 0.48), Offset(w + 10, h * 0.48), paintRoad);

    // Draw inner thin road divider line
    final paintDivider = Paint()
      ..color = const Color(0xFFEFECE9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(w * 0.5, -10),
      Offset(w * 0.5, h + 10),
      paintDivider,
    );
    canvas.drawLine(
      Offset(-10, h * 0.48),
      Offset(w + 10, h * 0.48),
      paintDivider,
    );

    // Draw park block (soft green zone)
    final paintPark = Paint()
      ..color = const Color(0xFFE2F0D9)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.7, h * 0.1, w * 0.2, h * 0.2),
        const Radius.circular(8),
      ),
      paintPark,
    );

    // Draw radar wave circle around pin
    final paintRadar = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.5, h * 0.48), 28.0, paintRadar);
    canvas.drawCircle(Offset(w * 0.5, h * 0.48), 14.0, paintRadar);

    // Location pin (red dot)
    final paintPin = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.5, h * 0.48), 7.0, paintPin);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
