import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/auth/rider_auth_bloc.dart';
import '../../bloc/auth/rider_auth_event.dart';
import '../../bloc/auth/rider_auth_state.dart';
import '../../constants/route_constants.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';

class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key});

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _vehicleNumController = TextEditingController();
  String _selectedVehicleType = 'Motorcycle';

  final List<String> _vehicleTypes = [
    'Motorcycle',
    'Scooter',
    'Electric Vehicle (EV)',
    'Bicycle',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _vehicleNumController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      context.read<RiderAuthBloc>().add(
            SaveRiderProfileEvent(
              name: _nameController.text.trim(),
              vehicleType: _selectedVehicleType,
              vehicleNumber: _vehicleNumController.text.trim().toUpperCase(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    return Scaffold(
      body: BlocConsumer<RiderAuthBloc, RiderAuthState>(
        listener: (context, state) {
          if (state is RiderAuthSuccessState) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              RouteConstants.dashboard,
              (route) => false,
            );
          } else if (state is RiderAuthFailureState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is RiderAuthLoading;

          return CommonBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(24)),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: Responsive.h(30)),
                      CustomText.heading(
                        'Rider Profile Setup',
                        fontSize: Responsive.sp(22),
                        fontWeight: FontWeight.bold,
                      ),
                      SizedBox(height: Responsive.h(6)),
                      CustomText.body(
                        'Provide your details to begin receiving delivery tasks',
                        fontSize: Responsive.sp(13),
                        color: AppColors.grayFont,
                      ),
                      SizedBox(height: Responsive.h(32)),

                      // Full Name
                      CustomText.title('Full Name *', fontSize: Responsive.sp(14)),
                      SizedBox(height: Responsive.h(6)),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Ramesh Kumar',
                          filled: true,
                          fillColor: AppColors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Responsive.w(12)),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your name' : null,
                      ),
                      SizedBox(height: Responsive.h(20)),

                      // Vehicle Type Dropdown
                      CustomText.title('Vehicle Type *', fontSize: Responsive.sp(14)),
                      SizedBox(height: Responsive.h(6)),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: Responsive.w(12)),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(Responsive.w(12)),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedVehicleType,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                            items: _vehicleTypes.map((type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Row(
                                  children: [
                                    const Icon(Icons.two_wheeler_rounded, size: 20, color: AppColors.grayFont),
                                    SizedBox(width: Responsive.w(10)),
                                    Text(type),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedVehicleType = val);
                              }
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: Responsive.h(20)),

                      // Vehicle Number
                      CustomText.title('Vehicle Registration Number *', fontSize: Responsive.sp(14)),
                      SizedBox(height: Responsive.h(6)),
                      TextFormField(
                        controller: _vehicleNumController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'e.g. KA-01-AB-1234',
                          filled: true,
                          fillColor: AppColors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Responsive.w(12)),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primary),
                        ),
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? 'Please enter your vehicle plate number' : null,
                      ),
                      SizedBox(height: Responsive.h(36)),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: Responsive.h(52),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _onSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Responsive.w(14)),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : Text(
                                  'Complete Registration',
                                  style: TextStyle(
                                    fontSize: Responsive.sp(16),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
        },
      ),
    );
  }
}
