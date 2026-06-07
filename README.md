# Zivofit - Aura Health App 🚀

An ultra-premium, dark-themed fitness, nutrition, and physique tracker application built with Flutter. Zivofit delivers a "digital cockpit" dashboard experience to manage daily goals, log food, analyze nutrition, log workouts, and track physical transformations side-by-side.

## 🎨 Tech Stack & Architecture

- **Frontend Framework**: Flutter (Stable Channel)
- **State Management**: Flutter Riverpod
- **Local Storage**: Hive (for lightning-fast local metadata/metrics caching)
- **Backend / Authentication**: Firebase Auth, Cloud Firestore, Cloud Functions (proxying AI analysis queries safely), and Cloud Storage (for physique photos)
- **Design Language**: Luminous low-light glassmorphism dark mode ("Obsidian Velvet" & "Space Sapphire" gradients with neon highlights)
- **CI/CD Integration**: GitHub Actions workflow for automatic Android APK compilation (`Build Release APK` pipeline)

---

## ✨ Features

### 📊 Luminous Dashboard
- **Metabolic Rings**: Dynamic visual progress tracking of calorie goals, protein, carbs, fat, and hydration.
- **Dynamic Metrics Editor**: Tapping "Edit" on the main card launches a blur-background metrics panel to override daily calories, macronutrient targets, and water intake.
- **Embedded Daily History**: Inline log tracker showing every item logged on the selected day, with immediate editing/removal options.

### 🍎 Food Journaling & AI Scanning
- **AI Photo Scan**: Upload or take a picture of a meal for automated calorie and macronutrient parsing. Includes disclaimer notices and manual overrides.
- **Barcode Scanner**: ZXing-powered quick item scanning on both web and mobile environments.
- **Food Timelines**: The history screen maps all logs dynamically to see when meals were eaten, allowing users to modify or delete logs retroactively.

### 🏋️ Workout Tracker & Physique Analyzer
- **Session Recorder**: Record specific weights, sets, and reps with smooth tap-to-adjust controls.
- **Physique Photo Journal**: Upload daily progress pictures linked directly to dates.
- **Side-by-Side Comparison Slider**:
  - Compare progress on different dates side-by-side with a drag slider.
  - Automatic dropdown date collision prevention (the app separates the selected `Before` and `After` photos automatically when at least two photos exist).
  - Floating fullscreen comparison popup with **Fit Screen** (`BoxFit.contain`) and **Fill Screen** (`BoxFit.cover`) toggles to view vertical photos without head cropping.

---

## 🛠️ Configuration & Setup

### Environment Requirements
- Flutter SDK `^3.12.0` (with web and mobile channels enabled)
- Java 17+ (configured via JDK)

### Local Configuration
1. Initialize the packages:
   ```bash
   flutter pub get
   ```
2. Configure Firebase:
   - Place a valid [google-services.json](file:///c:/Users/smogg/Downloads/v2/healthapp/codemvpv1/android/app/google-services.json) in `android/app/`.
   - Initialize configurations using `flutterfire configure` if modifying project structures.

3. Run the application:
   - For Web:
     ```bash
     flutter run -d chrome
     ```
   - For Android (Native):
     ```bash
     flutter run -d android
     ```

### CI/CD Workflow
- The project includes a pre-configured GitHub Action workflow in `.github/workflows/build_apk.yml` that compiles the release package on push or pull requests to the `main` branch.
- Cross-platform helper wrappers are used (e.g. `web_notification_helper.dart`) to prevent compilation errors of web-specific elements (`dart:js`) on native targets.
