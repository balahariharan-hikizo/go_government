import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';
import 'complaint_image_widget.dart';

/// Interactive full-screen image preview dialog with pinch-to-zoom and pan support.
class ImagePreviewDialog extends StatelessWidget {
  final String? imagePath;
  final File? file;
  final String? title;
  final String? subtitle;

  const ImagePreviewDialog({
    super.key,
    this.imagePath,
    this.file,
    this.title,
    this.subtitle,
  });

  /// Opens the interactive full-screen photo preview dialog.
  static Future<void> show(
    BuildContext context, {
    String? imagePath,
    File? file,
    String? title,
    String? subtitle,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Image Preview',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) {
        return ImagePreviewDialog(
          imagePath: imagePath,
          file: file,
          title: title,
          subtitle: subtitle,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Interactive Pinch & Zoom Image Viewer
            Center(
              child: InteractiveViewer(
                clipBehavior: Clip.none,
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.8,
                maxScale: 4.5,
                child: file != null
                    ? Image.file(
                        file!,
                        fit: BoxFit.contain,
                      )
                    : ComplaintImageWidget(
                        imagePath: imagePath,
                        fit: BoxFit.contain,
                      ),
              ),
            ),

            // Top App Bar with Details & Close Button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(16),
                  vertical: Responsive.h(10),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    // Close Button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: EdgeInsets.all(Responsive.w(8)),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    SizedBox(width: Responsive.w(12)),

                    // Title & Subtitle Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title?.isNotEmpty == true ? title! : 'Photo Preview',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: Responsive.sp(14),
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle?.isNotEmpty == true) ...[
                            SizedBox(height: Responsive.h(2)),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: Responsive.sp(11),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Hint Bar
            Positioned(
              bottom: Responsive.h(16),
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(14),
                    vertical: Responsive.h(6),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(Responsive.w(20)),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pinch_outlined, color: Colors.white70, size: 16),
                      SizedBox(width: Responsive.w(6)),
                      Text(
                        'Pinch to zoom • Drag to pan',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: Responsive.sp(11),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
