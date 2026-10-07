import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../network/store_api_service.dart';
import '../../bloc/store/store_bloc.dart';
import '../../bloc/store/store_event.dart';
import '../../bloc/store/store_state.dart';
import '../../constants/route_constants.dart';
import '../../model/bank_details_model.dart';
import '../../model/store_model.dart';
import '../../services/location_service.dart';
import '../../constants/google_config.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/custom_text.dart';

class RegisterStoreScreen extends StatefulWidget {
  final String initialPhone;

  const RegisterStoreScreen({
    super.key,
    required this.initialPhone,
  });

  @override
  State<RegisterStoreScreen> createState() => _RegisterStoreScreenState();
}

class _RegisterStoreScreenState extends State<RegisterStoreScreen> {
  final _formKey = GlobalKey<FormState>();

  // 1. Store Identity
  late final TextEditingController _nameController;
  late final TextEditingController _storeImageController;

  // 2. Merchant Contact
  late final TextEditingController _ownerNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  // 3. Location & GPS
  late final TextEditingController _addressController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  // 4. Bank Details
  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _confirmAccountController;
  late final TextEditingController _ifscController;
  late final TextEditingController _accountHolderController;

  // 5. Timings
  late final TextEditingController _openTimeController;
  late final TextEditingController _closeTimeController;

  String _selectedCategory = 'ration';
  bool _isFetchingGps = false;
  File? _pickedImageFile;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;

  final List<Map<String, String>> _categories = [
    {'id': 'ration', 'name': 'Fair-Price Ration Depot (PDS)', 'icon': '🌾'},
    {'id': 'medical', 'name': 'Civic Pharmacy / Medical', 'icon': '💊'},
    {'id': 'vegstore', 'name': 'Horticulture & Farm Fresh', 'icon': '🥦'},
    {'id': 'supermarket', 'name': 'Cooperative Supermarket', 'icon': '🛒'},
    {'id': 'dairy', 'name': 'Aavin / Dairy Outlet', 'icon': '🥛'},
    {'id': 'general', 'name': 'Essential Commodities Store', 'icon': '🏪'},
  ];

  final List<String> _popularBanks = [
    'State Bank of India',
    'Indian Bank',
    'Canara Bank',
    'HDFC Bank',
    'ICICI Bank',
  ];

  @override
  void initState() {
    super.initState();
    // Clean fields - no hardcoded mock data
    _nameController = TextEditingController();
    _storeImageController = TextEditingController();

    _ownerNameController = TextEditingController();
    _phoneController = TextEditingController(text: widget.initialPhone);
    _emailController = TextEditingController();

    _addressController = TextEditingController();
    _pincodeController = TextEditingController();
    _latController = TextEditingController(text: '13.0827');
    _lngController = TextEditingController(text: '80.2707');

    _bankNameController = TextEditingController();
    _accountNumberController = TextEditingController();
    _confirmAccountController = TextEditingController();
    _ifscController = TextEditingController();
    _accountHolderController = TextEditingController();

    _openTimeController = TextEditingController(text: '08:00 AM');
    _closeTimeController = TextEditingController(text: '08:30 PM');

    // Auto sync Holder Name when Owner Name typed
    _ownerNameController.addListener(() {
      if (_accountHolderController.text.isEmpty ||
          _accountHolderController.text == _ownerNameController.text) {
        _accountHolderController.text = _ownerNameController.text;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _storeImageController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _confirmAccountController.dispose();
    _ifscController.dispose();
    _accountHolderController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    super.dispose();
  }

  Future<void> _fetchDeviceGps() async {
    setState(() => _isFetchingGps = true);
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;

    if (pos != null) {
      _latController.text = pos.latitude.toStringAsFixed(5);
      _lngController.text = pos.longitude.toStringAsFixed(5);

      final geo = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
      if (!mounted) return;

      setState(() {
        _isFetchingGps = false;
        if (geo.address.isNotEmpty) _addressController.text = geo.address;
        if (geo.pincode.isNotEmpty) _pincodeController.text = geo.pincode;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📍 GPS location fetched: ${geo.area.isNotEmpty ? geo.area : 'Current location'}'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() => _isFetchingGps = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not fetch GPS. Please choose location on the map.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openMapPicker() async {
    final double curLat = double.tryParse(_latController.text) ?? 13.0827;
    final double curLng = double.tryParse(_lngController.text) ?? 80.2707;

    final result = await Navigator.of(context).pushNamed(
      RouteConstants.pickLocation,
      arguments: {
        'initialLocation': LatLng(curLat, curLng),
        'initialAddress': _addressController.text,
      },
    );

    if (result != null && result is StoreLocationResult && mounted) {
      setState(() {
        _latController.text = result.latitude.toStringAsFixed(5);
        _lngController.text = result.longitude.toStringAsFixed(5);
        if (result.address.isNotEmpty) _addressController.text = result.address;
        if (result.pincode.isNotEmpty) _pincodeController.text = result.pincode;
      });
    }
  }

  Future<void> _pickStoreImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Responsive.w(20))),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: Responsive.h(12)),
            child: Wrap(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(20), vertical: Responsive.h(8)),
                  child: CustomText.title('Select Storefront Photo', fontSize: 16, color: AppColors.black),
                ),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(Responsive.w(8)),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 22),
                  ),
                  title: CustomText.title('Take Photo with Camera', fontSize: 14),
                  subtitle: CustomText.body('Capture shop or signboard', fontSize: 12, color: AppColors.grayFont),
                  onTap: () async {
                    Navigator.of(bc).pop();
                    final XFile? image = await _imagePicker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 1280,
                      maxHeight: 1280,
                      imageQuality: 80,
                    );
                    if (image != null && mounted) {
                      setState(() {
                        _pickedImageFile = File(image.path);
                      });
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(Responsive.w(8)),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: AppColors.primary, size: 22),
                  ),
                  title: CustomText.title('Choose from Gallery', fontSize: 14),
                  subtitle: CustomText.body('Select photo from device album', fontSize: 12, color: AppColors.grayFont),
                  onTap: () async {
                    Navigator.of(bc).pop();
                    final XFile? image = await _imagePicker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1280,
                      maxHeight: 1280,
                      imageQuality: 80,
                    );
                    if (image != null && mounted) {
                      setState(() {
                        _pickedImageFile = File(image.path);
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    if (_accountNumberController.text.trim() != _confirmAccountController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bank account numbers do not match'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    String finalImageUrl = _storeImageController.text.trim();

    if (_pickedImageFile != null) {
      setState(() => _isUploadingImage = true);
      try {
        final uploaded = await StoreApiService.uploadStoreImage(_pickedImageFile!.path);
        if (uploaded != null && uploaded.isNotEmpty) {
          finalImageUrl = uploaded;
        }
      } catch (e) {
        debugPrint('Failed to upload store image: $e');
      } finally {
        if (mounted) setState(() => _isUploadingImage = false);
      }
    }

    final newStore = StoreModel(
      name: _nameController.text.trim(),
      ownerName: _ownerNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      category: _selectedCategory,
      address: _addressController.text.trim(),
      pincode: _pincodeController.text.trim(),
      lat: double.tryParse(_latController.text.trim()) ?? 13.0827,
      lng: double.tryParse(_lngController.text.trim()) ?? 80.2707,
      storeImage: finalImageUrl,
      bankDetails: BankDetailsModel(
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        ifscCode: _ifscController.text.trim().toUpperCase(),
        accountHolderName: _accountHolderController.text.trim().isNotEmpty
            ? _accountHolderController.text.trim()
            : _ownerNameController.text.trim(),
      ),
      timings: {
        'open': _openTimeController.text.trim(),
        'close': _closeTimeController.text.trim(),
      },
    );

    if (mounted) {
      context.read<StoreBloc>().add(RegisterStoreEvent(newStore));
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final double curLat = double.tryParse(_latController.text) ?? 13.0827;
    final double curLng = double.tryParse(_lngController.text) ?? 80.2707;

    return BlocConsumer<StoreBloc, StoreState>(
      listener: (context, state) {
        if (state is StoreSubmitSuccess) {
          Navigator.of(context).pushReplacementNamed(
            RouteConstants.applicationStatus,
            arguments: {'store': state.store, 'justSubmitted': true},
          );
        } else if (state is StoreError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is StoreSubmitting;

        return Scaffold(
          backgroundColor: AppColors.screenColor,
          appBar: AppBar(
            title: CustomText.header('Register Store', fontSize: 18, color: AppColors.black),
            backgroundColor: AppColors.screenColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(20), vertical: Responsive.h(12)),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Banner
                  Container(
                    padding: EdgeInsets.all(Responsive.w(16)),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(Responsive.w(16)),
                      border: Border.all(color: AppColors.outliner.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(Responsive.w(8)),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
                        ),
                        SizedBox(width: Responsive.w(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomText.title(
                                'Civic Commercial Registration',
                                fontSize: 14,
                                color: AppColors.primary,
                              ),
                              SizedBox(height: Responsive.h(4)),
                              CustomText.body(
                                'Register your shop with accurate GPS pin & settlement bank details. Municipal officers review applications within 24-48 hours.',
                                fontSize: 12,
                                color: AppColors.grayFont,
                                height: 1.3,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: Responsive.h(20)),

                  // 1. Store Details
                  _buildSectionHeader('1. Store Identity & Category'),
                  _buildFormCard([
                    _buildTextField(
                      controller: _nameController,
                      label: 'Store / Outlet Name',
                      hint: 'e.g. Cauvery Fair Price Depot',
                      validator: (v) => v == null || v.isEmpty ? 'Store name required' : null,
                    ),
                    SizedBox(height: Responsive.h(14)),
                    _buildCategoryDropdown(),
                    SizedBox(height: Responsive.h(14)),
                    _buildStoreImagePicker(),
                  ]),
                  SizedBox(height: Responsive.h(20)),

                  // 2. Owner Details
                  _buildSectionHeader('2. Merchant / Manager Contact'),
                  _buildFormCard([
                    _buildTextField(
                      controller: _ownerNameController,
                      label: 'Owner Full Name',
                      hint: 'e.g. B. Balahariharan',
                      validator: (v) => v == null || v.isEmpty ? 'Owner name required' : null,
                    ),
                    SizedBox(height: Responsive.h(14)),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Contact Mobile Number',
                      hint: '9876543210',
                      keyboardType: TextInputType.phone,
                      readOnly: widget.initialPhone.isNotEmpty,
                      suffix: widget.initialPhone.isNotEmpty
                          ? Container(
                              padding: EdgeInsets.symmetric(horizontal: Responsive.w(8), vertical: Responsive.h(4)),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(Responsive.w(8)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 14),
                                  SizedBox(width: Responsive.w(4)),
                                  CustomText.title('OTP Verified', fontSize: 11, color: const Color(0xFF2E7D32)),
                                ],
                              ),
                            )
                          : null,
                      validator: (v) => v == null || v.length < 10 ? 'Enter valid 10-digit mobile' : null,
                    ),
                    SizedBox(height: Responsive.h(14)),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email Address (Optional)',
                      hint: 'store@gmail.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ]),
                  SizedBox(height: Responsive.h(20)),

                  // 3. Location & GPS Address
                  _buildSectionHeader('3. Store Location & GPS Mapping'),
                  _buildFormCard([
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.map_rounded, size: 18, color: Colors.white),
                            label: CustomText.title('Choose on Map', fontSize: 13, color: Colors.white),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(vertical: Responsive.h(12)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
                            ),
                            onPressed: _openMapPicker,
                          ),
                        ),
                        SizedBox(width: Responsive.w(10)),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: _isFetchingGps
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  )
                                : const Icon(Icons.my_location_rounded, size: 18, color: AppColors.primary),
                            label: CustomText.title(
                              _isFetchingGps ? 'Detecting...' : 'Use Current GPS',
                              fontSize: 13,
                              color: AppColors.primary,
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary, width: 1.2),
                              padding: EdgeInsets.symmetric(vertical: Responsive.h(12)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(12))),
                            ),
                            onPressed: _isFetchingGps ? null : _fetchDeviceGps,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(14)),

                    // Mini Map Preview
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Responsive.w(14)),
                      child: Container(
                        height: Responsive.h(140),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.outliner.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(Responsive.w(14)),
                        ),
                        child: Stack(
                          children: [
                            FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(curLat, curLng),
                                initialZoom: 15.0,
                                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                                onTap: (tapPosition, point) => _openMapPicker(),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: GoogleConfig.googleTileUrl,
                                  subdomains: GoogleConfig.googleTileSubdomains,
                                  maxZoom: 20,
                                  userAgentPackageName: 'com.hikizo.storeapp',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(curLat, curLng),
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.topCenter,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                          boxShadow: const [
                                            BoxShadow(color: Colors.black26, blurRadius: 4),
                                          ],
                                        ),
                                        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Positioned(
                              right: Responsive.w(10),
                              bottom: Responsive.h(10),
                              child: InkWell(
                                onTap: _openMapPicker,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(10), vertical: Responsive.h(6)),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    borderRadius: BorderRadius.circular(Responsive.w(8)),
                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.open_in_full_rounded, size: 12, color: AppColors.primary),
                                      SizedBox(width: Responsive.w(4)),
                                      CustomText.title('Full Map', fontSize: 11, color: AppColors.primary),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.h(14)),

                    _buildTextField(
                      controller: _addressController,
                      label: 'Street Address & Landmark',
                      hint: 'Door No, Street Name, Commercial complex',
                      maxLines: 2,
                      validator: (v) => v == null || v.isEmpty ? 'Address required' : null,
                    ),
                    SizedBox(height: Responsive.h(14)),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _pincodeController,
                            label: 'Postal Pincode',
                            hint: '600040',
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.length != 6 ? '6-digit pincode' : null,
                          ),
                        ),
                        SizedBox(width: Responsive.w(12)),
                        Expanded(
                          child: _buildTextField(
                            controller: _latController,
                            label: 'Latitude (GPS)',
                            hint: '13.0827',
                            readOnly: true,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        SizedBox(width: Responsive.w(8)),
                        Expanded(
                          child: _buildTextField(
                            controller: _lngController,
                            label: 'Longitude (GPS)',
                            hint: '80.2707',
                            readOnly: true,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                  ]),
                  SizedBox(height: Responsive.h(20)),

                  // 4. Bank Details
                  _buildSectionHeader('4. Settlement Bank Account Details'),
                  _buildFormCard([
                    CustomText.body(
                      'Civic subsidies, DBT vouchers, and merchant settlements are disbursed directly to this verified bank account.',
                      fontSize: 12,
                      color: AppColors.grayFont,
                      height: 1.3,
                    ),
                    SizedBox(height: Responsive.h(10)),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _popularBanks.map((b) {
                          final isSelected = _bankNameController.text == b;
                          return Padding(
                            padding: EdgeInsets.only(right: Responsive.w(8)),
                            child: ChoiceChip(
                              label: Text(b, style: TextStyle(fontSize: Responsive.sp(11), fontWeight: FontWeight.w600)),
                              selected: isSelected,
                              selectedColor: AppColors.primary.withValues(alpha: 0.15),
                              labelStyle: TextStyle(color: isSelected ? AppColors.primary : AppColors.black),
                              onSelected: (_) {
                                setState(() => _bankNameController.text = b);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: Responsive.h(12)),

                    _buildTextField(
                      controller: _bankNameController,
                      label: 'Bank Name',
                      hint: 'e.g. State Bank of India',
                      validator: (v) => v == null || v.isEmpty ? 'Bank name required' : null,
                    ),
                    SizedBox(height: Responsive.h(14)),

                    _buildTextField(
                      controller: _accountHolderController,
                      label: 'Account Holder Name',
                      hint: 'Full name as printed in bank passbook',
                      validator: (v) => v == null || v.isEmpty ? 'Account holder name required' : null,
                    ),
                    SizedBox(height: Responsive.h(14)),

                    _buildTextField(
                      controller: _accountNumberController,
                      label: 'Bank Account Number',
                      hint: 'e.g. 30948192841',
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.length < 8 ? 'Enter valid account number' : null,
                    ),
                    SizedBox(height: Responsive.h(14)),

                    _buildTextField(
                      controller: _confirmAccountController,
                      label: 'Re-Enter Account Number',
                      hint: 'Confirm your account number',
                      keyboardType: TextInputType.number,
                      validator: (v) => v != _accountNumberController.text ? 'Account numbers do not match' : null,
                    ),
                    SizedBox(height: Responsive.h(14)),

                    _buildTextField(
                      controller: _ifscController,
                      label: 'IFSC Code',
                      hint: 'e.g. SBIN0000842',
                      keyboardType: TextInputType.text,
                      validator: (v) {
                        if (v == null || v.length < 8) return 'Enter valid IFSC code (11 characters)';
                        return null;
                      },
                    ),
                  ]),
                  SizedBox(height: Responsive.h(20)),

                  // 5. Operating Hours
                  _buildSectionHeader('5. Operating Timings'),
                  _buildFormCard([
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _openTimeController,
                            label: 'Opening Time',
                            hint: '08:00 AM',
                          ),
                        ),
                        SizedBox(width: Responsive.w(14)),
                        Expanded(
                          child: _buildTextField(
                            controller: _closeTimeController,
                            label: 'Closing Time',
                            hint: '08:30 PM',
                          ),
                        ),
                      ],
                    ),
                  ]),
                  SizedBox(height: Responsive.h(28)),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: Responsive.h(54),
                    child: ElevatedButton(
                      onPressed: (isLoading || _isUploadingImage) ? null : _submitRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Responsive.w(16)),
                        ),
                        elevation: 0,
                      ),
                      child: (isLoading || _isUploadingImage)
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                ),
                                SizedBox(width: Responsive.w(10)),
                                CustomText.title(
                                  _isUploadingImage ? 'Uploading Store Photo...' : 'Submitting Store...',
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ],
                            )
                          : CustomText.title(
                              'Submit Store Registration',
                              fontSize: 16,
                              color: Colors.white,
                            ),
                    ),
                  ),
                  SizedBox(height: Responsive.h(36)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStoreImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CustomText.title('Storefront Photo', fontSize: 13, color: AppColors.black),
            Container(
              padding: EdgeInsets.symmetric(horizontal: Responsive.w(8), vertical: Responsive.h(2)),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Responsive.w(6)),
              ),
              child: CustomText.body('Recommended', fontSize: 11, color: AppColors.primary),
            ),
          ],
        ),
        SizedBox(height: Responsive.h(8)),
        if (_pickedImageFile != null)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Responsive.w(14)),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
              color: Colors.white,
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(Responsive.w(12))),
                  child: Image.file(
                    _pickedImageFile!,
                    height: Responsive.h(160),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 18),
                      SizedBox(width: Responsive.w(6)),
                      Expanded(
                        child: CustomText.body(
                          'Storefront photo selected',
                          fontSize: 12,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickStoreImage,
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
                        label: CustomText.title('Change', fontSize: 12, color: AppColors.primary),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: Responsive.w(8)),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _pickedImageFile = null;
                            _storeImageController.clear();
                          });
                        },
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                        tooltip: 'Remove photo',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          InkWell(
            onTap: _pickStoreImage,
            borderRadius: BorderRadius.circular(Responsive.w(14)),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: Responsive.h(22), horizontal: Responsive.w(16)),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(Responsive.w(14)),
                border: Border.all(color: AppColors.outliner, width: 1.2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: Responsive.w(52),
                    height: Responsive.w(52),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_a_photo_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  SizedBox(height: Responsive.h(10)),
                  CustomText.title(
                    'Upload Storefront Photo',
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: Responsive.h(4)),
                  CustomText.body(
                    'Take photo with camera or choose from gallery',
                    fontSize: 11,
                    color: AppColors.grayFont,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.h(8), left: Responsive.w(4)),
      child: CustomText.title(title, fontSize: 14, color: AppColors.black),
    );
  }

  Widget _buildFormCard(List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Responsive.w(18)),
        border: Border.all(color: AppColors.outliner.withValues(alpha: 0.4)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomText.title(label, fontSize: 13, color: AppColors.black),
        SizedBox(height: Responsive.h(6)),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          validator: validator,
          style: TextStyle(
            fontSize: Responsive.sp(14),
            fontWeight: FontWeight.w600,
            color: readOnly ? AppColors.grayFont : AppColors.black,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: Responsive.sp(13), color: AppColors.grayFont.withValues(alpha: 0.6)),
            filled: true,
            fillColor: readOnly ? AppColors.lightGray.withValues(alpha: 0.5) : AppColors.lightGray,
            suffixIcon: suffix != null
                ? Padding(
                    padding: EdgeInsets.only(right: Responsive.w(12)),
                    child: UnconstrainedBox(child: suffix),
                  )
                : null,
            contentPadding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(12)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.w(14)),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.w(14)),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomText.title('Store Category', fontSize: 13, color: AppColors.black),
        SizedBox(height: Responsive.h(6)),
        DropdownButtonFormField<String>(
          initialValue: _selectedCategory,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.lightGray,
            contentPadding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(12)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.w(14)),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.w(14)),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          items: _categories.map((c) {
            return DropdownMenuItem(
              value: c['id'],
              child: Row(
                children: [
                  Text(c['icon']!, style: const TextStyle(fontSize: 16)),
                  SizedBox(width: Responsive.w(8)),
                  Text(
                    c['name']!,
                    style: TextStyle(fontSize: Responsive.sp(13), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedCategory = val);
          },
        ),
      ],
    );
  }
}
