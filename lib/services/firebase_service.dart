import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import 'storage_service.dart';

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

  /// Sync Local (Hive) Data up to Cloud Firestore
  static Future<void> syncLocalToCloud() async {
    final user = currentUser;
    if (user == null) return;

    final uid = user.uid;
    final userDoc = firestore.collection('users').doc(uid);

    try {
      // 1. Profile Sync
      final profile = StorageService.getUserProfile();
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
        metricsBatch.set(docRef, metrics);
      }
      await metricsBatch.commit();

      debugPrint("Firebase cloud sync completed successfully.");
    } catch (e) {
      debugPrint("Error syncing local to cloud: $e");
    }
  }

  /// Sync Cloud Firestore Data down to Local (Hive)
  static Future<void> syncCloudToLocal() async {
    final user = currentUser;
    if (user == null) return;

    final uid = user.uid;
    final userDoc = firestore.collection('users').doc(uid);

    try {
      final docSnap = await userDoc.get();
      if (!docSnap.exists) {
        // No remote data yet, push local data to server
        await syncLocalToCloud();
        return;
      }

      final data = docSnap.data() ?? {};

      // 1. Profile Sync
      final profileMap = data['profile'] as Map?;
      if (profileMap != null) {
        final profile = UserProfile(
          goal: profileMap['goal'] ?? 'lose',
          age: profileMap['age'] ?? 25,
          weight: (profileMap['weight'] as num?)?.toDouble() ?? 70.0,
          height: (profileMap['height'] as num?)?.toDouble() ?? 175.0,
          activityLevel: profileMap['activityLevel'] ?? 'moderate',
          calorieGoal: profileMap['calorieGoal'] ?? 2000,
          proteinGoal: profileMap['proteinGoal'] ?? 140,
          waterGoal: profileMap['waterGoal'] ?? 2500,
          gender: profileMap['gender'] ?? 'male',
          skinType: profileMap['skinType'] ?? 'Normal',
        );
        await StorageService.saveUserProfile(profile);
      }

      // 2. Reminders Sync
      final remindersMap = data['reminders'] as Map?;
      if (remindersMap != null) {
        await StorageService.saveReminders(Map<String, dynamic>.from(remindersMap));
      }

      // 3. Favorite Foods Sync
      final favList = data['favorite_foods'] as List?;
      if (favList != null) {
        for (final fav in favList) {
          await StorageService.saveFavoriteFood(Map<String, dynamic>.from(fav));
        }
      }

      // 4. Pinned Widgets Sync
      final pinnedList = data['pinned_widgets'] as List?;
      if (pinnedList != null) {
        await StorageService.savePinnedWidgets(List<String>.from(pinnedList));
      }

      // 5. Workouts Sync
      final workoutsSnap = await userDoc.collection('workouts').get();
      for (final doc in workoutsSnap.docs) {
        await StorageService.saveWorkout(doc.data());
      }

      // 6. Daily Metrics Sync
      final metricsSnap = await userDoc.collection('daily_metrics').get();
      for (final doc in metricsSnap.docs) {
        await StorageService.saveDailyMetrics(doc.id, doc.data());
      }

      debugPrint("Firebase cloud sync to local completed.");
    } catch (e) {
      debugPrint("Error syncing cloud to local: $e");
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
}
