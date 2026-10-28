import 'package:flutter/material.dart';
import '../../hive/hive_service.dart';
import '../../services/translation_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguageCode = 'en';

  @override
  void initState() {
    super.initState();
    _selectedLanguageCode = HiveService.getLanguageCode();
  }


  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'nativeName': 'English', 'icon': 'A'},
    {'code': 'kn', 'name': 'Kannada', 'nativeName': 'ಕನ್ನಡ', 'icon': 'ಕ'},
    {'code': 'hi', 'name': 'Hindi', 'nativeName': 'हिंदी', 'icon': 'अ'},
    {'code': 'te', 'name': 'Telugu', 'nativeName': 'తెలుగు', 'icon': 'తె'},
    {'code': 'ta', 'name': 'Tamil', 'nativeName': 'தமிழ்', 'icon': 'த'},
    {'code': 'ml', 'name': 'Malayalam', 'nativeName': 'മലയാളം', 'icon': 'മ'},
    {'code': 'mr', 'name': 'Marathi', 'nativeName': 'मराठी', 'icon': 'म'},
    {'code': 'bn', 'name': 'Bengali', 'nativeName': 'বাংলা', 'icon': 'বা'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenColor,
      body: CommonBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Scrollable content grid
              Positioned.fill(
                child: Column(
                  children: [
                    SizedBox(height: Responsive.h(70)),
                    
                    // Introductory Text
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText.header(
                            'Choose your language',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          SizedBox(height: Responsive.h(6)),
                          CustomText.subtitle(
                            'Please select your preferred language to customize your app experience.',
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: Responsive.h(20)),

                    // Grid of impressive language cards
                    Expanded(
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.w(20),
                          vertical: Responsive.h(10),
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: Responsive.w(14),
                          mainAxisSpacing: Responsive.h(14),
                          childAspectRatio: 1.15,
                        ),
                        itemCount: _languages.length,
                        itemBuilder: (context, index) {
                          final lang = _languages[index];
                          final bool isSelected = lang['code'] == _selectedLanguageCode;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedLanguageCode = lang['code']!;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFFF6F3) : AppColors.white,
                                borderRadius: BorderRadius.circular(Responsive.w(20)),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.outliner,
                                  width: Responsive.w(isSelected ? 2.0 : 1.2),
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.15),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        )
                                      ],
                              ),
                              padding: EdgeInsets.all(Responsive.w(14)),
                              child: Stack(
                                children: [
                                  // Selected Checkmark indicator top right
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: Container(
                                      width: Responsive.w(20),
                                      height: Responsive.w(20),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected ? AppColors.primary : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: Responsive.w(12),
                                            )
                                          : null,
                                    ),
                                  ),

                                  // Main language content
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // Decorative language letter circle
                                      Container(
                                        width: Responsive.w(38),
                                        height: Responsive.w(38),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.primary.withValues(alpha: 0.15)
                                              : Colors.grey.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          lang['icon']!,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? AppColors.primary : AppColors.black,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        lang['nativeName']!,
                                        style: TextStyle(
                                          fontFamily: 'Valley Sans',
                                          fontSize: Responsive.sp(16),
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.black,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: Responsive.h(2)),
                                      Text(
                                        lang['name']!,
                                        style: TextStyle(
                                          fontFamily: 'Valley Sans',
                                          fontSize: Responsive.sp(12),
                                          color: Colors.grey.shade500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Save button
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.w(20),
                        vertical: Responsive.h(20),
                      ),
                      child: GestureDetector(
                        onTap: () {
                          final selectedLang = _languages.firstWhere((l) => l['code'] == _selectedLanguageCode);
                          TranslationService.setLanguage(selectedLang['code']!, selectedLang['name'] ?? 'English');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Language changed to ${selectedLang['name']} successfully!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: double.infinity,
                          height: Responsive.h(50),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(Responsive.w(25)),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          alignment: Alignment.center,
                          child: CustomText.title(
                            'Save Language',
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Custom Header Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: Responsive.h(60),
                  color: AppColors.screenColor.withValues(alpha: 0.95),
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
                      Expanded(
                        child: CustomText.header(
                          'Select Language',
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
