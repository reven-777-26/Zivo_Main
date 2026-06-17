import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/user_profile.dart';
import 'storage_service.dart';
import '../features/vision_lens/shared/services/vision_storage_service.dart';

class FirebaseService {
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Stream of user auth state changes.
  static Stream<User?> get authStateChanges =>
      Firebase.apps.isNotEmpty ? auth.authStateChanges() : const Stream.empty();

  /// Gets current user.
  static User? get currentUser => Firebase.apps.isNotEmpty ? auth.currentUser : null;

  /// Check if user is logged in.
  static bool get isLoggedIn => Firebase.apps.isNotEmpty && currentUser != null;

  /// Check if the user is anonymous.
  static bool get isAnonymous => Firebase.apps.isNotEmpty && (currentUser?.isAnonymous ?? false);

  /// Log in anonymously (Guest Mode)
  static Future<UserCredential> signInAnonymously() async {
    if (Firebase.apps.isEmpty) {
      throw Exception("Firebase is not initialized. Please configure Firebase to use auth.");
    }
    try {
      final credential = await auth.signInAnonymously();
      // Initialize or sync data
      await syncCloudToLocal();
      return credential;
    } catch (e) {
      debugPrint("Firebase anonymous auth error: $e");
      rethrow;
    }
  }

  /// Sign Up with Email and Password
  static Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    if (Firebase.apps.isEmpty) {
      throw Exception("Firebase is not initialized. Please configure Firebase to use auth.");
    }
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Upload existing local data to new account
      await syncLocalToCloud();
      return credential;
    } catch (e) {
      debugPrint("Firebase Sign Up Error: $e");
      rethrow;
    }
  }

  /// Sign In with Email and Password
  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (Firebase.apps.isEmpty) {
      throw Exception("Firebase is not initialized. Please configure Firebase to use auth.");
    }
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Sync cloud data down to Hive
      await syncCloudToLocal();
      return credential;
    } catch (e) {
      debugPrint("Firebase Sign In Error: $e");
      rethrow;
    }
  }

  /// Send Password Reset Email
  static Future<void> sendPasswordResetEmail(String email) async {
    if (Firebase.apps.isEmpty) {
      throw Exception("Firebase is not initialized. Please configure Firebase to use auth.");
    }
    try {
      await auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint("Firebase Password Reset Error: $e");
      rethrow;
    }
  }

  /// Sign In with Google
  static Future<UserCredential?> signInWithGoogle() async {
    if (Firebase.apps.isEmpty) {
      throw Exception("Firebase is not initialized. Please configure Firebase to use auth.");
    }
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final credential = await auth.signInWithPopup(googleProvider);
        await syncCloudToLocal();
        return credential;
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCred = await auth.signInWithCredential(credential);
        await syncCloudToLocal();
        return userCred;
      }
    } catch (e) {
      debugPrint("Firebase Google Sign In Error: $e");
      rethrow;
    }
  }

  /// Sign Out
  static Future<void> signOut() async {
    if (Firebase.apps.isEmpty) {
      // If Firebase is not available, we still want to clean local storage.
      await StorageService.clearAllData();
      return;
    }
    try {
      await auth.signOut();
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      // Clear local Hive data on logout to ensure clean state
      await StorageService.clearAllData();
    } catch (e) {
      debugPrint("Firebase Sign Out Error: $e");
    }
  }

  /// Deletes the current user's authentication account and all associated Firestore data
  static Future<void> deleteUserAccountForever() async {
    if (Firebase.apps.isEmpty) {
      await StorageService.clearAllData();
      return;
    }
    final user = currentUser;
    if (user == null) return;
    final uid = user.uid;

    try {
      final userDoc = firestore.collection('users').doc(uid);

      // Delete workouts subcollection
      final workouts = await userDoc.collection('workouts').get();
      for (final doc in workouts.docs) {
        await doc.reference.delete();
      }

      // Delete daily_metrics subcollection
      final metrics = await userDoc.collection('daily_metrics').get();
      for (final doc in metrics.docs) {
        await doc.reference.delete();
      }

      // Delete scans subcollection
      final scans = await userDoc.collection('scans').get();
      for (final doc in scans.docs) {
        await doc.reference.delete();
      }

      // Delete user settings document
      await userDoc.delete();

      // Delete the Firebase Auth user
      try {
        await user.delete();
      } on FirebaseAuthException catch (authErr) {
        if (authErr.code == 'admin-restricted-operation') {
          debugPrint("User account deletion is restricted by admin policy. Signing out instead.");
          await auth.signOut();
        } else {
          rethrow;
        }
      } catch (e) {
        rethrow;
      }

      // Clear local Hive database data
      await StorageService.clearAllData();
      debugPrint("User account and all cloud data deleted forever.");
    } catch (e) {
      debugPrint("Error deleting user account: $e");
      rethrow;
    }
  }

  /// Sync Local (Hive) Data up to Cloud Firestore
  static Future<void> syncLocalToCloud({BuildContext? context}) async {
    final user = currentUser;
    if (user == null) return;

    final uid = user.uid;
    final userDoc = firestore.collection('users').doc(uid);

    try {
      // 0. Root Metadata Sync (allows easy user lookup for admins in console)
      final email = user.email;
      await userDoc.set({
        'uid': uid,
        if (email != null) 'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 1. Profile Sync
      final profile = StorageService.getUserProfile();
      final displayName = user.displayName;
      if (displayName != null) {
        await userDoc.set({'displayName': displayName}, SetOptions(merge: true));
      }
      if (profile != null) {
        await userDoc.set({
          'profile': {
            'goal': profile.goal,
            'age': profile.age,
            'weight': profile.weight,
            'height': profile.height,
            'activityLevel': profile.activityLevel,
            'calorieGoal': profile.calorieGoal,
            'proteinGoal': profile.proteinGoal,
            'waterGoal': profile.waterGoal,
            'gender': profile.gender,
            'skinType': profile.skinType,
          }
        }, SetOptions(merge: true));
      }

      // 2. Reminders Sync
      final reminders = StorageService.getReminders();
      await userDoc.set({'reminders': reminders}, SetOptions(merge: true));

      // 3. Favorite Foods Sync
      final favorites = StorageService.getFavoriteFoods();
      await userDoc.set({'favorite_foods': favorites}, SetOptions(merge: true));

      // 4. Pinned Widgets Sync
      final pinned = StorageService.getPinnedWidgets();
      await userDoc.set({'pinned_widgets': pinned}, SetOptions(merge: true));

      // 5. Workouts Sync
      final workouts = StorageService.getWorkouts();
      final workoutBatch = firestore.batch();
      for (final w in workouts) {
        final id = w['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
        final docRef = userDoc.collection('workouts').doc(id);
        workoutBatch.set(docRef, w);
      }
      await workoutBatch.commit();

      // 6. Daily Metrics Sync (past 45 days)
      final dates = StorageService.getAllLoggedDates();
      final metricsBatch = firestore.batch();
      for (final date in dates) {
        final docRef = userDoc.collection('daily_metrics').doc(date);
        final metrics = StorageService.getDailyMetrics(date);
        
        // Intercept and upload any legacy offline base64 physique photos
        final String? gymPic = metrics['gym_pic'] as String?;
        if (gymPic != null && !gymPic.startsWith('http')) {
          final url = await uploadPhysiquePhoto(
            uid: uid,
            dateStr: date,
            base64Content: gymPic,
          );
          if (url != null) {
            metrics['gym_pic'] = url;
            // Persist the URL reference locally so we don't upload again
            await StorageService.saveDailyMetrics(date, metrics);
          }
        }

        // Intercept and upload any legacy offline base64 food photos inside logged_items
        final List? items = metrics['logged_items'] as List?;
        if (items != null) {
          bool updatedAny = false;
          final List<Map<String, dynamic>> updatedItems = [];
          for (int i = 0; i < items.length; i++) {
            final item = Map<String, dynamic>.from(items[i]);
            final String? foodPic = item['imageUrl'] as String?;
            if (foodPic != null && !foodPic.startsWith('http')) {
              final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
              final url = await uploadFoodPhoto(
                uid: uid,
                dateStr: date,
                fileName: 'item_${i}_$timestamp',
                base64Content: foodPic,
              );
              if (url != null) {
                item['imageUrl'] = url;
                updatedAny = true;
              }
            }
            updatedItems.add(item);
          }
          if (updatedAny) {
            metrics['logged_items'] = updatedItems;
            await StorageService.saveDailyMetrics(date, metrics);
          }
        }
        
        metricsBatch.set(docRef, metrics);
      }
      await metricsBatch.commit();

      // 7. Scans Sync
      final scansList = StorageService.getRecentScans();
      final scansBatch = firestore.batch();
      for (final s in scansList) {
        final name = s['name'] ?? DateTime.now().millisecondsSinceEpoch.toString();
        final safeDocId = name.toString().replaceAll('/', '_').replaceAll(' ', '_');
        final docRef = userDoc.collection('scans').doc(safeDocId);
        scansBatch.set(docRef, s);
      }
      await scansBatch.commit();

      // 8. Workout Templates Sync
      final templates = StorageService.getWorkoutTemplates();
      final templatesBatch = firestore.batch();
      for (final t in templates) {
        final name = t['name'] ?? 'template_${DateTime.now().millisecondsSinceEpoch}';
        final safeId = name.toString().replaceAll('/', '_').replaceAll(' ', '_');
        final docRef = userDoc.collection('workout_templates').doc(safeId);
        templatesBatch.set(docRef, t);
      }
      await templatesBatch.commit();

      // 9. App Settings Sync (accent color, macro goals, notification prefs)
      await userDoc.set({
        'settings': {
          'accentColorIndex': StorageService.getAccentColorIndex(),
          'carbsGoal': StorageService.getCarbsGoal(),
          'fatsGoal': StorageService.getFatsGoal(),
          'auraNotificationsEnabled': StorageService.getAuraNotificationsEnabled(),
          'systemNotificationsEnabled': StorageService.getSystemNotificationsEnabled(),
        }
      }, SetOptions(merge: true));

      // 10. Profile Picture Sync (upload base64 to Storage, store URL)
      final profilePicBase64 = StorageService.getProfilePicture();
      if (profilePicBase64 != null && profilePicBase64.isNotEmpty && !profilePicBase64.startsWith('http')) {
        final url = await _uploadBase64Image(
          uid: uid,
          storagePath: 'users/$uid/profile_picture.jpg',
          base64Content: profilePicBase64,
        );
        if (url != null) {
          await userDoc.set({'profilePictureUrl': url}, SetOptions(merge: true));
          // Persist URL locally so we don't re-upload
          await StorageService.saveProfilePicture(url);
        }
      } else if (profilePicBase64 != null && profilePicBase64.startsWith('http')) {
        // Already a URL, just ensure it's in Firestore
        await userDoc.set({'profilePictureUrl': profilePicBase64}, SetOptions(merge: true));
      }

      // 11. Custom Background Sync (upload base64 to Storage, store URL)
      final bgBase64 = StorageService.getCustomBackground();
      if (bgBase64 != null && bgBase64.isNotEmpty && !bgBase64.startsWith('http')) {
        final url = await _uploadBase64Image(
          uid: uid,
          storagePath: 'users/$uid/custom_background.jpg',
          base64Content: bgBase64,
        );
        if (url != null) {
          await userDoc.set({'customBackgroundUrl': url}, SetOptions(merge: true));
          await StorageService.saveCustomBackground(url);
        }
      } else if (bgBase64 != null && bgBase64.startsWith('http')) {
        await userDoc.set({'customBackgroundUrl': bgBase64}, SetOptions(merge: true));
      }

      // 12. Vision Scan History Sync (user's personal scan analysis results)
      for (final category in ['food', 'supplement', 'skincare']) {
        try {
          final history = await VisionStorageService.getHistory(category);
          if (history.isNotEmpty) {
            final visionBatch = firestore.batch();
            for (final item in history) {
              final barcode = item['barcode']?.toString() ?? item['productName']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
              final safeId = barcode.replaceAll('/', '_').replaceAll(' ', '_');
              final docRef = userDoc.collection('vision_${category}_history').doc(safeId);
              // Remove non-serializable fields and ensure clean data
              final cleanItem = Map<String, dynamic>.from(item);
              cleanItem.remove('barcode'); // barcode is the doc ID
              visionBatch.set(docRef, cleanItem);
            }
            await visionBatch.commit();
          }
        } catch (e) {
          debugPrint("Error syncing vision $category history: $e");
        }
      }

      debugPrint("Firebase cloud sync completed successfully.");
    } catch (e) {
      debugPrint("Error syncing local to cloud: $e");
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Cloud Upload Sync Failed: ${e.toString().replaceFirst('Exception: ', '')}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Sync Cloud Firestore Data down to Local (Hive)
  static Future<void> syncCloudToLocal({BuildContext? context}) async {
    final user = currentUser;
    if (user == null) return;

    final uid = user.uid;
    final userDoc = firestore.collection('users').doc(uid);

    try {
      // 1. Fetch user doc containing profile, reminders, favorite foods, pinned widgets
      final doc = await userDoc.get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          // 1.1 Profile
          final profileMap = data['profile'] as Map?;
          if (profileMap != null) {
            final profile = UserProfile(
              goal: profileMap['goal']?.toString() ?? 'lose',
              age: (profileMap['age'] as num?)?.toInt() ?? 26,
              weight: (profileMap['weight'] as num?)?.toDouble() ?? 78.4,
              height: (profileMap['height'] as num?)?.toDouble() ?? 182.0,
              activityLevel: profileMap['activityLevel']?.toString() ?? 'moderate',
              calorieGoal: (profileMap['calorieGoal'] as num?)?.toInt() ?? 2200,
              proteinGoal: (profileMap['proteinGoal'] as num?)?.toInt() ?? 150,
              waterGoal: (profileMap['waterGoal'] as num?)?.toInt() ?? 3000,
              gender: profileMap['gender']?.toString() ?? 'male',
              skinType: profileMap['skinType']?.toString() ?? 'Normal',
            );
            await StorageService.saveUserProfile(profile);
          }

          // 1.2 Reminders
          final remindersMap = data['reminders'] as Map?;
          if (remindersMap != null) {
            await StorageService.saveReminders(Map<String, dynamic>.from(remindersMap));
          }

          // 1.3 Favorite Foods
          final favsList = data['favorite_foods'] as List?;
          if (favsList != null) {
            await StorageService.saveFavoriteFoodsList(
              favsList.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            );
          }

          // 1.4 Pinned Widgets
          final pinnedList = data['pinned_widgets'] as List?;
          if (pinnedList != null) {
            await StorageService.savePinnedWidgets(List<String>.from(pinnedList));
          }

          // 1.5 Display Name
          final nameStr = data['displayName'] as String?;
          if (nameStr != null && nameStr != user.displayName) {
            await user.updateDisplayName(nameStr);
            await user.reload();
          }
        }
      }

      // 2. Fetch Workouts from subcollection
      final workoutsSnap = await userDoc.collection('workouts').get();
      final List<Map<String, dynamic>> workoutsList = [];
      for (final doc in workoutsSnap.docs) {
        workoutsList.add(doc.data());
      }
      await StorageService.saveWorkoutsList(workoutsList);

      // 3. Fetch Daily Metrics from subcollection
      final metricsSnap = await userDoc.collection('daily_metrics').get();
      for (final doc in metricsSnap.docs) {
        await StorageService.saveDailyMetrics(doc.id, doc.data());
      }

      // 4. Fetch Scans from subcollection
      final scansSnap = await userDoc.collection('scans').get();
      final List<Map<String, dynamic>> scansList = [];
      for (final doc in scansSnap.docs) {
        scansList.add(doc.data());
      }
      await StorageService.saveRecentScansList(scansList);

      // 5. Fetch Workout Templates from subcollection
      final templatesSnap = await userDoc.collection('workout_templates').get();
      if (templatesSnap.docs.isNotEmpty) {
        for (final doc in templatesSnap.docs) {
          await StorageService.saveWorkoutTemplate(doc.data());
        }
      }

      // 6. Fetch App Settings
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final settingsMap = data['settings'] as Map?;
          if (settingsMap != null) {
            final accentIdx = (settingsMap['accentColorIndex'] as num?)?.toInt();
            if (accentIdx != null) await StorageService.saveAccentColorIndex(accentIdx);
            final carbsG = (settingsMap['carbsGoal'] as num?)?.toInt();
            if (carbsG != null) await StorageService.saveCarbsGoal(carbsG);
            final fatsG = (settingsMap['fatsGoal'] as num?)?.toInt();
            if (fatsG != null) await StorageService.saveFatsGoal(fatsG);
            final auraNotif = settingsMap['auraNotificationsEnabled'] as bool?;
            if (auraNotif != null) await StorageService.setAuraNotificationsEnabled(auraNotif);
            final sysNotif = settingsMap['systemNotificationsEnabled'] as bool?;
            if (sysNotif != null) await StorageService.setSystemNotificationsEnabled(sysNotif);
          }

          // 6.1 Profile Picture URL
          final profilePicUrl = data['profilePictureUrl'] as String?;
          if (profilePicUrl != null && profilePicUrl.isNotEmpty) {
            await StorageService.saveProfilePicture(profilePicUrl);
          }

          // 6.2 Custom Background URL
          final bgUrl = data['customBackgroundUrl'] as String?;
          if (bgUrl != null && bgUrl.isNotEmpty) {
            await StorageService.saveCustomBackground(bgUrl);
          }
        }
      }

      // 7. Fetch Vision Scan History (user's personal analysis results)
      for (final category in ['food', 'supplement', 'skincare']) {
        try {
          final visionSnap = await userDoc.collection('vision_${category}_history').get();
          for (final vDoc in visionSnap.docs) {
            final data = vDoc.data();
            data['barcode'] = vDoc.id;
            await VisionStorageService.cacheProduct(category, vDoc.id, data);
          }
        } catch (e) {
          debugPrint("Error syncing vision $category history down: $e");
        }
      }

      debugPrint("Firebase cloud down-sync completed successfully.");
    } catch (e) {
      debugPrint("Error syncing cloud to local: $e");
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Cloud Download Sync Failed: ${e.toString().replaceFirst('Exception: ', '')}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }



  /// Clears daily metrics and workouts collections in cloud Firestore
  static Future<void> clearMockDataCloud() async {
    if (!isLoggedIn) return;
    try {
      final userDoc = firestore.collection('users').doc(currentUser!.uid);
      
      // Clear workouts
      final workoutsSnap = await userDoc.collection('workouts').get();
      for (final doc in workoutsSnap.docs) {
        await doc.reference.delete();
      }
      
      // Clear daily metrics
      final metricsSnap = await userDoc.collection('daily_metrics').get();
      for (final doc in metricsSnap.docs) {
        await doc.reference.delete();
      }
      debugPrint("Firebase cloud mock data cleared.");
    } catch (e) {
      debugPrint("Error clearing cloud mock data: $e");
    }
  }

  /// Sync specific profile update
  static Future<void> saveProfileCloud(UserProfile profile) async {
    if (!isLoggedIn) return;
    try {
      await firestore.collection('users').doc(currentUser!.uid).set({
        'profile': {
          'goal': profile.goal,
          'age': profile.age,
          'weight': profile.weight,
          'height': profile.height,
          'activityLevel': profile.activityLevel,
          'calorieGoal': profile.calorieGoal,
          'proteinGoal': profile.proteinGoal,
          'waterGoal': profile.waterGoal,
          'gender': profile.gender,
          'skinType': profile.skinType,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error syncing single profile: $e");
    }
  }

  /// Sync specific daily metrics update
  static Future<void> saveDailyMetricsCloud(String dateStr, Map<String, dynamic> metrics) async {
    if (!isLoggedIn) return;
    try {
      await firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('daily_metrics')
          .doc(dateStr)
          .set(metrics);
    } catch (e) {
      debugPrint("Error syncing single metric: $e");
    }
  }

  /// Sync specific workout session
  static Future<void> saveWorkoutCloud(Map<String, dynamic> workout) async {
    if (!isLoggedIn) return;
    try {
      final id = workout['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      await firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('workouts')
          .doc(id)
          .set(workout);
    } catch (e) {
      debugPrint("Error syncing single workout: $e");
    }
  }

  /// Sync reminders update
  static Future<void> saveRemindersCloud(Map<String, dynamic> reminders) async {
    if (!isLoggedIn) return;
    try {
      await firestore.collection('users').doc(currentUser!.uid).set({
        'reminders': reminders
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error syncing reminders: $e");
    }
  }

  /// Sync a workout template to cloud
  static Future<void> saveWorkoutTemplateCloud(Map<String, dynamic> template) async {
    if (!isLoggedIn) return;
    try {
      final name = template['name'] ?? 'template_${DateTime.now().millisecondsSinceEpoch}';
      final safeId = name.toString().replaceAll('/', '_').replaceAll(' ', '_');
      await firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('workout_templates')
          .doc(safeId)
          .set(template);
    } catch (e) {
      debugPrint("Error syncing workout template: $e");
    }
  }

  /// Delete a workout template from cloud
  static Future<void> deleteWorkoutTemplateCloud(String templateName) async {
    if (!isLoggedIn) return;
    try {
      final safeId = templateName.replaceAll('/', '_').replaceAll(' ', '_');
      await firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('workout_templates')
          .doc(safeId)
          .delete();
    } catch (e) {
      debugPrint("Error deleting workout template from cloud: $e");
    }
  }

  /// Sync app settings (accent color, macro goals, notification prefs) to cloud
  static Future<void> saveSettingsCloud() async {
    if (!isLoggedIn) return;
    try {
      await firestore.collection('users').doc(currentUser!.uid).set({
        'settings': {
          'accentColorIndex': StorageService.getAccentColorIndex(),
          'carbsGoal': StorageService.getCarbsGoal(),
          'fatsGoal': StorageService.getFatsGoal(),
          'auraNotificationsEnabled': StorageService.getAuraNotificationsEnabled(),
          'systemNotificationsEnabled': StorageService.getSystemNotificationsEnabled(),
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error syncing settings: $e");
    }
  }

  /// Sync a vision scan history item to the user's personal cloud history
  static Future<void> saveVisionHistoryCloud(String category, String barcode, Map<String, dynamic> data) async {
    if (!isLoggedIn) return;
    try {
      final safeId = barcode.replaceAll('/', '_').replaceAll(' ', '_');
      final cleanData = Map<String, dynamic>.from(data);
      cleanData.remove('barcode');
      await firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('vision_${category.toLowerCase()}_history')
          .doc(safeId)
          .set(cleanData);
    } catch (e) {
      debugPrint("Error syncing vision history item: $e");
    }
  }

  /// Sync profile picture to cloud (upload base64 or persist existing URL)
  static Future<void> saveProfilePictureCloud(String? base64OrUrl) async {
    if (!isLoggedIn || base64OrUrl == null || base64OrUrl.isEmpty) return;
    try {
      final uid = currentUser!.uid;
      if (!base64OrUrl.startsWith('http')) {
        final url = await _uploadBase64Image(
          uid: uid,
          storagePath: 'users/$uid/profile_picture.jpg',
          base64Content: base64OrUrl,
        );
        if (url != null) {
          await firestore.collection('users').doc(uid).set(
            {'profilePictureUrl': url}, SetOptions(merge: true),
          );
          await StorageService.saveProfilePicture(url);
        }
      } else {
        await firestore.collection('users').doc(uid).set(
          {'profilePictureUrl': base64OrUrl}, SetOptions(merge: true),
        );
      }
    } catch (e) {
      debugPrint("Error syncing profile picture: $e");
    }
  }

  /// Sync custom background to cloud (upload base64 or persist existing URL)
  static Future<void> saveCustomBackgroundCloud(String? base64OrUrl) async {
    if (!isLoggedIn || base64OrUrl == null || base64OrUrl.isEmpty) return;
    try {
      final uid = currentUser!.uid;
      if (!base64OrUrl.startsWith('http')) {
        final url = await _uploadBase64Image(
          uid: uid,
          storagePath: 'users/$uid/custom_background.jpg',
          base64Content: base64OrUrl,
        );
        if (url != null) {
          await firestore.collection('users').doc(uid).set(
            {'customBackgroundUrl': url}, SetOptions(merge: true),
          );
          await StorageService.saveCustomBackground(url);
        }
      } else {
        await firestore.collection('users').doc(uid).set(
          {'customBackgroundUrl': base64OrUrl}, SetOptions(merge: true),
        );
      }
    } catch (e) {
      debugPrint("Error syncing custom background: $e");
    }
  }

  /// Helper: Upload a base64 image to Firebase Storage and return the download URL
  static Future<String?> _uploadBase64Image({
    required String uid,
    required String storagePath,
    required String base64Content,
  }) async {
    if (Firebase.apps.isEmpty) return null;
    try {
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      String cleanBase64 = base64Content;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      final bytes = base64Decode(cleanBase64.replaceAll(RegExp(r'\s+'), ''));
      final compressedBytes = _compressImageBytes(bytes) ?? bytes;
      final task = ref.putData(compressedBytes, SettableMetadata(contentType: 'image/jpeg'));
      final snap = await task;
      return await snap.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Firebase Storage base64 upload error: $e");
      return null;
    }
  }

  /// Retrieves a cached scan from Firestore by barcode and category.
  static Future<Map<String, dynamic>?> getScanFromCloud(String barcode, String category) async {
    if (!isLoggedIn) return null;
    try {
      final collectionName = category == 'Food'
          ? 'global_food_scans'
          : (category == 'Supplement' ? 'global_supplement_scans' : 'global_skincare_scans');
      final doc = await firestore
          .collection(collectionName)
          .doc(barcode)
          .get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      debugPrint("Error loading scan from Firestore: $e");
    }
    return null;
  }

  /// Saves an analyzed scan to Firestore.
  static Future<void> saveScanToCloud(String barcode, String category, Map<String, dynamic> scanData) async {
    if (!isLoggedIn) return;
    try {
      final collectionName = category == 'Food'
          ? 'global_food_scans'
          : (category == 'Supplement' ? 'global_supplement_scans' : 'global_skincare_scans');
      await firestore
          .collection(collectionName)
          .doc(barcode)
          .set(scanData);
    } catch (e) {
      debugPrint("Error saving scan to Firestore: $e");
    }
  }

  static Uint8List? _compressImageBytes(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      img.Image resized = decoded;
      if (decoded.width > 512 || decoded.height > 512) {
        resized = img.copyResize(
          decoded,
          width: decoded.width > decoded.height ? 512 : null,
          height: decoded.height >= decoded.width ? 512 : null,
        );
      }
      return Uint8List.fromList(img.encodeJpg(resized, quality: 70));
    } catch (e) {
      debugPrint("Failed to compress image bytes: $e");
      return null;
    }
  }

  /// Uploads a physique photo (either via filePath or base64) to Firebase Storage.
  /// Returns the public download URL of the uploaded image.
  static Future<String?> uploadPhysiquePhoto({
    required String uid,
    required String dateStr,
    String? filePath,
    String? base64Content,
  }) async {
    if (Firebase.apps.isEmpty) return null;
    try {
      final ref = FirebaseStorage.instance.ref().child('users/$uid/physique/$dateStr.jpg');
      
      Uint8List bytes;
      if (!kIsWeb && filePath != null && filePath.isNotEmpty) {
        bytes = await File(filePath).readAsBytes();
      } else if (base64Content != null && base64Content.isNotEmpty) {
        String cleanBase64 = base64Content;
        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last;
        }
        bytes = base64Decode(cleanBase64.replaceAll(RegExp(r'\s+'), ''));
      } else {
        return null;
      }

      final compressedBytes = _compressImageBytes(bytes) ?? bytes;
      final task = ref.putData(compressedBytes, SettableMetadata(contentType: 'image/jpeg'));
      
      final snap = await task;
      final url = await snap.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint("Firebase Storage Upload Error: $e");
      return null;
    }
  }

  /// Uploads a food photo (via base64 or file path) to Firebase Storage under users/$uid/food/
  /// Returns the public download URL of the uploaded image.
  static Future<String?> uploadFoodPhoto({
    required String uid,
    required String dateStr,
    required String fileName,
    String? filePath,
    String? base64Content,
  }) async {
    if (Firebase.apps.isEmpty) return null;
    try {
      final ref = FirebaseStorage.instance.ref().child('users/$uid/food/$dateStr/$fileName.jpg');
      
      Uint8List bytes;
      if (!kIsWeb && filePath != null && filePath.isNotEmpty) {
        bytes = await File(filePath).readAsBytes();
      } else if (base64Content != null && base64Content.isNotEmpty) {
        String cleanBase64 = base64Content;
        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last;
        }
        bytes = base64Decode(cleanBase64.replaceAll(RegExp(r'\s+'), ''));
      } else {
        return null;
      }

      final compressedBytes = _compressImageBytes(bytes) ?? bytes;
      final task = ref.putData(compressedBytes, SettableMetadata(contentType: 'image/jpeg'));
      
      final snap = await task;
      final url = await snap.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint("Firebase Storage Food Upload Error: $e");
      return null;
    }
  }

  /// Deletes a physique photo from Firebase Storage.
  static Future<void> deletePhysiquePhoto({
    required String uid,
    required String dateStr,
  }) async {
    if (Firebase.apps.isEmpty) return;
    try {
      final ref = FirebaseStorage.instance.ref().child('users/$uid/physique/$dateStr.jpg');
      await ref.delete();
    } catch (e) {
      debugPrint("Firebase Storage Delete Error (expected if file doesn't exist): $e");
    }
  }
}
