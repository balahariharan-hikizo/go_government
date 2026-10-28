import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class CallLauncher {
  static const MethodChannel _dialerChannel =
      MethodChannel('com.hikizo.goGovernment/dialer');

  /// Launches a phone dialer for the given phone number with multi-level fallbacks.
  static Future<void> launchCall(
    BuildContext context, {
    required String phone,
    String? name,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '').trim();

    if (cleanPhone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number is not available for this store.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    bool launched = false;

    // 1. Primary: Native Android Intent (ACTION_DIAL) via MethodChannel
    // This directly opens the OEM dialer (Vivo, Xiaomi, Samsung, etc.)
    // without requiring package-visibility queries or permission prompts.
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final res = await _dialerChannel.invokeMethod<bool>('dialNumber', {'phone': cleanPhone});
        if (res == true) {
          launched = true;
          debugPrint('[CallLauncher] Native Android ACTION_DIAL succeeded for $cleanPhone');
        }
      } catch (e) {
        debugPrint('[CallLauncher] Native dialer method channel failed or not yet recompiled: $e');
      }
    }

    // 2. Secondary: url_launcher using Uri.parse('tel:$cleanPhone')
    if (!launched) {
      final Uri telUri = Uri.parse('tel:$cleanPhone');

      // 2a. Try externalNonBrowserApplication
      try {
        launched = await launchUrl(
          telUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (e) {
        debugPrint('[CallLauncher] externalNonBrowserApplication failed: $e');
      }

      // 2b. Try platformDefault mode
      if (!launched) {
        try {
          launched = await launchUrl(
            telUri,
            mode: LaunchMode.platformDefault,
          );
        } catch (e) {
          debugPrint('[CallLauncher] platformDefault failed: $e');
        }
      }

      // 2c. Try Uri constructor
      if (!launched) {
        try {
          final Uri altUri = Uri(scheme: 'tel', path: cleanPhone);
          launched = await launchUrl(altUri);
        } catch (e) {
          debugPrint('[CallLauncher] Uri constructor launch failed: $e');
        }
      }
    }

    // 3. Fallback: If device cannot launch dialer directly, copy number to clipboard
    if (!launched && context.mounted) {
      await Clipboard.setData(ClipboardData(text: cleanPhone));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            name != null && name.isNotEmpty
                ? '$name: $cleanPhone (Copied to clipboard)'
                : 'Store phone: $cleanPhone (Copied to clipboard)',
          ),
          backgroundColor: Colors.blueGrey.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

