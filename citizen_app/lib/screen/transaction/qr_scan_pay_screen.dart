import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_success_screen.dart';

class QrScanPayScreen extends StatefulWidget {
  const QrScanPayScreen({super.key});

  @override
  State<QrScanPayScreen> createState() => _QrScanPayScreenState();
}

class _QrScanPayScreenState extends State<QrScanPayScreen> {
  bool _showSuccessScreen = false;
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccessScreen) {
      return _buildSuccessScreen();
    }
    return _buildScannerScreen();
  }

  Widget _buildScannerScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Real-time camera scanner background
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: (BarcodeCapture capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String? code = barcodes.first.rawValue;
                  if (code != null && !_showSuccessScreen) {
                    setState(() {
                      _showSuccessScreen = true;
                    });
                  }
                }
              },
            ),
          ),
          
          // Dark overlay with transparent center window
          Positioned.fill(
            child: Container(
              color: Colors.black45,
            ),
          ),

          SafeArea(
            child: Stack(
              children: [
                // Top Controls Bar
                Positioned(
                  top: Responsive.h(10),
                  left: Responsive.w(20),
                  right: Responsive.w(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.all(Responsive.w(8)),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _controller.toggleTorch(),
                            child: Container(
                              padding: EdgeInsets.all(Responsive.w(8)),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.flash_on, color: Colors.white, size: Responsive.w(20)),
                            ),
                          ),
                          SizedBox(width: Responsive.w(12)),
                          GestureDetector(
                            onTap: () => _controller.switchCamera(),
                            child: Container(
                              padding: EdgeInsets.all(Responsive.w(8)),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.flip_camera_ios, color: Colors.white, size: Responsive.w(20)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Center Scan Target Area
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showSuccessScreen = true;
                          });
                        },
                        child: Container(
                          width: Responsive.w(260),
                          height: Responsive.w(260),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFF4511E),
                              width: Responsive.w(3.0),
                            ),
                            borderRadius: BorderRadius.circular(Responsive.w(36)),
                            color: Colors.transparent,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(Responsive.w(33)),
                            child: Center(
                              child: Opacity(
                                opacity: 0.15,
                                child: Icon(
                                  Icons.qr_code_2,
                                  color: Colors.white,
                                  size: Responsive.w(180),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: Responsive.h(24)),

                      // Upload from gallery Pill Button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showSuccessScreen = true;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.w(20),
                            vertical: Responsive.h(10),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(Responsive.w(24)),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_library_outlined, color: Colors.white, size: Responsive.w(16)),
                              SizedBox(width: Responsive.w(8)),
                              const Text(
                                'Upload from gallery',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom descriptive label
                Positioned(
                  bottom: Responsive.h(60),
                  left: 0,
                  right: 0,
                  child: const Center(
                    child: Text(
                      'Scan any QR code to pay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 3.0,
                            color: Colors.black,
                          ),
                        ],
                      ),
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

  Widget _buildSuccessScreen() {
    return CommonSuccessScreen(
      amount: 100.0,
      title: 'Rakhesh',
      subtitle: 'Paid to',
      dateString: '6 June 2026, 2:42pm',
      buttonText: 'Done',
      onDone: () {
        Navigator.pop(context);
      },
    );
  }
}
