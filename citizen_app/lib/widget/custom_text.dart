import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../utils/responsive_helper.dart';
import '../services/translation_service.dart';
 
class CustomText extends StatelessWidget {

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
 
  const CustomText._({
    super.key,
    required this.text,
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });
 
  /// Section headers (e.g. "Good Morning, Ramesha..")
  factory CustomText.header(
    String text, {
    Key? key,
    Color color = AppColors.black,
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.bold,
    double? height,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return CustomText._(
      key: key,
      text: text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
      ),
    );
  }
 
  /// Title styles (e.g., card title or action headers)
  factory CustomText.title(
    String text, {
    Key? key,
    Color color = AppColors.black,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w600,
    double? height,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return CustomText._(
      key: key,
      text: text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
      ),
    );
  }
 
  /// Subtitle / Small styles (e.g., small body text, secondary labels)
  factory CustomText.subtitle(
    String text, {
    Key? key,
    Color color = AppColors.grayFont,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.normal,
    double? height,
    TextAlign? textAlign,
    TextDecoration? decoration,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return CustomText._(
      key: key,
      text: text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
      ),
    );
  }
 
  /// Body text styles (e.g., paragraph texts, description logs)
  factory CustomText.body(
    String text, {
    Key? key,
    Color color = AppColors.black,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    double? height,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return CustomText._(
      key: key,
      text: text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: TranslationService.languageNotifier,
      builder: (context, langCode, _) {
        final displayText = TranslationService.translateSync(text);
        return Text(
          displayText,
          style: style.copyWith(
            fontFamily: 'Valley Sans',
            fontSize: style.fontSize != null ? Responsive.sp(style.fontSize!) : null,
          ),
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}

