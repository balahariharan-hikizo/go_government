import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';
import '../../bloc/profile/profile_bloc.dart';
import '../../bloc/profile/profile_event.dart';
import '../../hive/hive_service.dart';
import '../../service/firebase_service.dart';
import '../../constants/route_constants.dart';
import '../../network/api_client.dart';
import '../../bloc/transaction/transaction_bloc.dart';
import '../../bloc/transaction/transaction_event.dart';
import '../../bloc/cart/cart_bloc.dart';
import '../../bloc/cart/cart_event.dart';

class EditProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final String initialImagePath;
  final bool isRegistration;

  const EditProfileScreen({
    super.key,
    this.initialName = '',
    this.initialEmail = '',
    this.initialImagePath = '',
    this.isRegistration = false,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  String _imagePath = '';
  final ImagePicker _picker = ImagePicker();

  bool _isModified = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _imagePath = widget.initialImagePath;

    _nameController.addListener(_checkModification);
    _emailController.addListener(_checkModification);
  }

  void _checkModification() {
    setState(() {
      _isModified = _nameController.text.trim() != widget.initialName ||
          _emailController.text.trim() != widget.initialEmail ||
          _imagePath != widget.initialImagePath;
    });
  }

  static final RegExp _emailRegExp =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  bool get _isValidEmail {
    final email = _emailController.text.trim();
    return _emailRegExp.hasMatch(email);
  }

  bool get _isValidName {
    final name = _nameController.text.trim();
    return name.length >= 3;
  }

  bool get _canSubmit {
    if (widget.isRegistration) {
      return _isValidName && _isValidEmail;
    }
    return _isModified && _isValidName && _isValidEmail;
  }

  String get _avatarInitial {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    if (widget.initialName.trim().isNotEmpty) {
      return widget.initialName.trim()[0].toUpperCase();
    }
    return '?';
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _imagePath = picked.path;
          _checkModification();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(Responsive.w(24)),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.w(20),
            vertical: Responsive.h(20),
          ),
          child: SafeArea(
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
                CustomText.header(
                  'Profile Picture',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
                SizedBox(height: Responsive.h(6)),
                CustomText.subtitle(
                  'Take a photo or choose from gallery',
                  fontSize: 13,
                  color: AppColors.grayFont,
                ),
                SizedBox(height: Responsive.h(20)),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(Responsive.w(10)),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF2EC),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.primary,
                      size: Responsive.w(22),
                    ),
                  ),
                  title: CustomText.title(
                    'Take Photo',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(Responsive.w(10)),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF2EC),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: AppColors.primary,
                      size: Responsive.w(22),
                    ),
                  ),
                  title: CustomText.title(
                    'Choose from Gallery',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_imagePath.isNotEmpty)
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(Responsive.w(10)),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: Responsive.w(22),
                      ),
                    ),
                    title: CustomText.title(
                      'Remove Photo',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _imagePath = '';
                        _checkModification();
                      });
                    },
                  ),
                SizedBox(height: Responsive.h(8)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (!_canSubmit) return;

    if (widget.isRegistration) {
      await HiveService.setUserName(name);
      await HiveService.setUserEmail(email);
      await HiveService.setLoggedIn(true);
      FirebaseService.syncFcmToken();
      if (!mounted) return;
      context.read<ProfileBloc>().add(UpdateProfileEvent(name, email, _imagePath));
      TransactionBloc.instance.add(LoadTransactionsEvent());
      CartBloc.instance.add(FetchCartAndWishlistEvent());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Registration completed successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Responsive.w(12)),
          ),
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        RouteConstants.permission,
        (route) => false,
        arguments: {'isFirstTime': true},
      );
    } else {
      Navigator.pop(context, {
        'name': name,
        'email': email,
        'imagePath': _imagePath,
      });
    }
  }

  Future<bool> _showExitConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Responsive.w(16)),
        ),
        title: CustomText.header('Exit App', fontSize: 18, fontWeight: FontWeight.bold),
        content: CustomText.title('Are you sure you want to exit the application?', fontSize: 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: CustomText.title('Cancel', color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: CustomText.title('Exit', color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildAvatarFallback() {
    return Center(
      child: _avatarInitial.isNotEmpty
          ? Text(
              _avatarInitial,
              style: TextStyle(
                fontSize: Responsive.sp(48),
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Valley Sans',
              ),
            )
          : Icon(
              Icons.add_a_photo_outlined,
              size: Responsive.w(42),
              color: Colors.white,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String normalizedPath = ApiClient.normalizeImageUrl(_imagePath);
    final bool isNetwork = normalizedPath.startsWith('http://') || normalizedPath.startsWith('https://');
    final bool isLocalFile = !isNetwork && normalizedPath.isNotEmpty && File(normalizedPath).existsSync();
    final bool hasImage = isNetwork || isLocalFile;

    final scaffold = Scaffold(
      backgroundColor: AppColors.screenColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: Responsive.w(70),
        leading: Padding(
          padding: EdgeInsets.only(left: Responsive.w(20)),
          child: Center(
            child: GestureDetector(
              onTap: () async {
                if (widget.isRegistration) {
                  final shouldExit = await _showExitConfirmationDialog();
                  if (shouldExit) {
                    SystemNavigator.pop();
                  }
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
          ),
        ),
        title: CustomText.header(
          widget.isRegistration ? 'Registration' : 'Edit Profile',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.black,
        ),
        centerTitle: false,
      ),
      body: CommonBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(24)),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        SizedBox(height: Responsive.h(20)),

                        // Profile image picker or dynamic 1st letter avatar
                        GestureDetector(
                          onTap: _showImagePickerModal,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: Responsive.w(120),
                                height: Responsive.w(120),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(Responsive.w(28)),
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: Responsive.w(2.5),
                                  ),
                                  gradient: hasImage
                                      ? null
                                      : const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFFFF9E80),
                                            AppColors.primary,
                                          ],
                                        ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.25),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(Responsive.w(25.5)),
                                  child: isNetwork
                                      ? Image.network(
                                          normalizedPath,
                                          width: Responsive.w(120),
                                          height: Responsive.w(120),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stack) => _buildAvatarFallback(),
                                        )
                                      : (isLocalFile
                                          ? Image.file(
                                              File(normalizedPath),
                                              width: Responsive.w(120),
                                              height: Responsive.w(120),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stack) => _buildAvatarFallback(),
                                            )
                                          : _buildAvatarFallback()),
                                ),
                              ),
                              // Camera / Edit badge
                              Positioned(
                                bottom: -Responsive.w(4),
                                right: -Responsive.w(4),
                                child: Container(
                                  padding: EdgeInsets.all(Responsive.w(8)),
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: Responsive.w(1.5),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    color: AppColors.primary,
                                    size: Responsive.w(18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: Responsive.h(10)),
                        CustomText.subtitle(
                          hasImage
                              ? 'Tap to change photo'
                              : (_avatarInitial.isNotEmpty
                                  ? 'Tap to change photo (Optional)'
                                  : 'Tap to add photo (Optional)'),
                          fontSize: 12,
                          color: AppColors.grayFont,
                        ),
                        SizedBox(height: Responsive.h(28)),

                        // Name input container with minimum 3 characters requirement
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(Responsive.w(16)),
                                border: Border.all(
                                  color: (_nameController.text.isNotEmpty && !_isValidName)
                                      ? AppColors.error
                                      : AppColors.outliner.withValues(alpha: 0.5),
                                  width: Responsive.w(1.2),
                                ),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.w(16),
                                vertical: Responsive.h(4),
                              ),
                              child: TextField(
                                controller: _nameController,
                                style: TextStyle(
                                  fontSize: Responsive.sp(15),
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.black,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Enter Name',
                                ),
                              ),
                            ),
                            if (_nameController.text.isNotEmpty && !_isValidName) ...[
                              SizedBox(height: Responsive.h(4)),
                              Padding(
                                padding: EdgeInsets.only(left: Responsive.w(8)),
                                child: CustomText.subtitle(
                                  'Name must be at least 3 characters',
                                  fontSize: 11,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: Responsive.h(16)),

                        // Email input container
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(Responsive.w(16)),
                                border: Border.all(
                                  color: (_emailController.text.isNotEmpty && !_isValidEmail)
                                      ? AppColors.error
                                      : AppColors.outliner.withValues(alpha: 0.5),
                                  width: Responsive.w(1.2),
                                ),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.w(16),
                                vertical: Responsive.h(4),
                              ),
                              child: TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: TextStyle(
                                  fontSize: Responsive.sp(15),
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.black,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Enter Email',
                                ),
                              ),
                            ),
                            if (_emailController.text.isNotEmpty && !_isValidEmail) ...[
                              SizedBox(height: Responsive.h(4)),
                              Padding(
                                padding: EdgeInsets.only(left: Responsive.w(8)),
                                child: CustomText.subtitle(
                                  'Please enter a valid email (e.g. name@example.com)',
                                  fontSize: 11,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Submit Button
                GestureDetector(
                  onTap: _submit,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: Responsive.h(50),
                    margin: EdgeInsets.only(bottom: Responsive.h(20)),
                    decoration: BoxDecoration(
                      color: _canSubmit ? AppColors.primary : const Color(0xFFF4EDE8),
                      borderRadius: BorderRadius.circular(Responsive.w(25)),
                      boxShadow: _canSubmit
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: CustomText.title(
                        widget.isRegistration ? 'Complete Registration' : 'Submit',
                        color: _canSubmit ? Colors.white : const Color(0xFFC0B3AC),
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
      ),
    );

    if (widget.isRegistration) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final shouldExit = await _showExitConfirmationDialog();
          if (shouldExit) {
            SystemNavigator.pop();
          }
        },
        child: scaffold,
      );
    }
    return scaffold;
  }
}
