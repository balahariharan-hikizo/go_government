import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../hive/hive_service.dart';
import '../network/auth_api_service.dart';
import '../services/notification_service.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static FirebaseStorage get _storage {
    try {
      return FirebaseStorage.instanceFor(bucket: 'gs://gogovernment.firebasestorage.app');
    } catch (_) {
      try {
        return FirebaseStorage.instanceFor(bucket: 'gogovernment.firebasestorage.app');
      } catch (_) {
        return FirebaseStorage.instance;
      }
    }
  }

  // Upload complaint image to Firebase Storage with reliable Base64 fallback
  static Future<String?> uploadComplaintImage(String localPath, String complaintId) async {
    try {
      final file = File(localPath);
      if (!file.existsSync()) {
        debugPrint('[FirebaseService] Local image does not exist: $localPath');
        return localPath;
      }

      // 1. Try Firebase Storage upload (creates https://firebasestorage.googleapis.com/... URL)
      try {
        final storageRef = _storage.ref().child('complaints').child('$complaintId.jpg');
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public,max-age=31536000',
        );
        final uploadTask = await storageRef.putFile(file, metadata);
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        debugPrint('[FirebaseService] Successfully uploaded to Firebase Storage: $downloadUrl');
        return downloadUrl;
      } catch (storageErr) {
        debugPrint('[FirebaseService] Firebase Storage upload error: $storageErr');
        debugPrint('[FirebaseService] If unauthorized, update Firebase Console -> Storage -> Rules to: allow read, write: if true;');
      }

      // 2. Base64 fallback for cross-device visibility if Firebase Storage rules are locked
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      return 'data:image/jpeg;base64,$b64';
    } catch (e) {
      debugPrint('[FirebaseService] uploadComplaintImage error: $e');
      return localPath;
    }
  }

  // 1. Submit a new complaint to Firestore
  static Future<void> submitComplaint(Map<String, dynamic> complaint) async {
    try {
      final docRef = _firestore.collection('complaints').doc(complaint['id']);
      
      // Add server timestamp for accurate real-time ordering
      final dataToSave = Map<String, dynamic>.from(complaint);
      dataToSave['timestamp'] = FieldValue.serverTimestamp();
      // Ensure we attach the device citizenId so we know whose complaint this is
      dataToSave['citizenId'] = HiveService.citizenId;

      await docRef.set(dataToSave);
      debugPrint('[FirebaseService] Successfully submitted complaint: ${complaint['id']}');
    } catch (e) {
      debugPrint('[FirebaseService] Error submitting complaint: $e');
    }
  }

  // 2. Stream ALL complaints from Firestore in real-time
  static Stream<List<Map<String, dynamic>>> streamAllComplaints() {
    return _firestore
        .collection('complaints')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // ensure ID is correct
        return data;
      }).toList();
    });
  }

  // 3. Toggle Like on a complaint
  static Future<void> toggleLike(String complaintId, bool isCurrentlyLiked) async {
    try {
      final docRef = _firestore.collection('complaints').doc(complaintId);
      final myCitizenId = HiveService.citizenId;

      if (!isCurrentlyLiked) {
        // Add like
        await docRef.update({
          'likedBy': FieldValue.arrayUnion([myCitizenId]),
          'likesCount': FieldValue.increment(1),
        });
      } else {
        // Remove like
        await docRef.update({
          'likedBy': FieldValue.arrayRemove([myCitizenId]),
          'likesCount': FieldValue.increment(-1),
        });
      }
    } catch (e) {
      debugPrint('[FirebaseService] Error toggling like: $e');
    }
  }

  // 4. Add Comment to a complaint
  static Future<void> addComment(String complaintId, String comment, String userName) async {
    try {
      final docRef = _firestore.collection('complaints').doc(complaintId);
      
      final newComment = {
        'userName': userName,
        'comment': comment,
        'date': 'Just now',
        'citizenId': HiveService.citizenId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await docRef.update({
        'comments': FieldValue.arrayUnion([newComment]),
      });
    } catch (e) {
      debugPrint('[FirebaseService] Error adding comment: $e');
    }
  }

  static String? _cachedFcmToken;

  /// Returns the current cached or retrieved FCM token
  static String? get cachedFcmToken => _cachedFcmToken;

  // 5. Initialize FCM and update device push token
  static Future<void> initFCM() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🔔 [FCM Citizen] Permission status: ${settings.authorizationStatus}');

      final token = await messaging.getToken();
      debugPrint('📱 [FCM Citizen] Device token: $token');
      if (token != null && token.isNotEmpty) {
        _cachedFcmToken = token;
        await syncFcmToken(token);
      }

      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 [FCM Citizen] Token refreshed: $newToken');
        _cachedFcmToken = newToken;
        await syncFcmToken(newToken);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📩 [FCM Foreground Citizen]: ${message.data}');
        final title = message.notification?.title ?? '📦 Order Update';
        final body = message.notification?.body ?? 'Your order status has been updated.';
        NotificationService.showOrderStatusNotification(
          title: title,
          body: body,
          orderId: message.data['orderId']?.toString(),
        );
      });
    } catch (e) {
      debugPrint('❌ [FCM Citizen] Init error: $e');
    }
  }

  /// Syncs FCM token to backend for the current logged-in citizen
  static Future<void> syncFcmToken([String? fcmToken]) async {
    try {
      final tokenToSync = fcmToken ?? _cachedFcmToken;
      if (tokenToSync == null || tokenToSync.isEmpty) {
        // Attempt to fetch from instance if not cached yet
        final fetchedToken = await FirebaseMessaging.instance.getToken();
        if (fetchedToken == null || fetchedToken.isEmpty) return;
        _cachedFcmToken = fetchedToken;
      }

      final activeToken = fcmToken ?? _cachedFcmToken!;
      final userId = HiveService.citizenId;
      final phone = HiveService.userPhone;
      final success = await AuthApiService.updateFcmToken(
        userId: userId,
        phone: phone,
        fcmToken: activeToken,
        role: 'citizen',
      );

      if (success) {
        debugPrint('✅ [FCM Citizen] Token successfully synced to backend via AuthApiService');
      } else {
        debugPrint('⚠️ [FCM Citizen] Backend returned failure updating FCM token');
      }
    } catch (e) {
      debugPrint('⚠️ [FCM Citizen] Failed to sync token to backend: $e');
    }
  }
}
