# Zivofit - Aura Health App 🚀

An ultra-premium, dark-themed fitness, nutrition, and physique tracker application built with Flutter. Zivofit delivers a "digital cockpit" dashboard experience to manage daily goals, log food, analyze nutrition, log workouts, and track physical transformations side-by-side.

## 🎨 Tech Stack & Architecture

- **Frontend Framework**: Flutter (Stable Channel)
- **State Management**: Flutter Riverpod
- **Local Storage**: Hive (for lightning-fast local metadata/metrics caching)
- **Backend / Authentication**: Firebase Auth, Cloud Firestore, Cloud Functions (Node.js 24), and Cloud Storage (for physique photos)
- **AI Engine**: Gemini 2.5 Flash integrated server-side via Firebase Cloud Functions
- **Design Language**: Luminous low-light glassmorphism dark mode ("Obsidian Velvet" & "Space Sapphire" gradients with neon highlights)
- **CI/CD Integration**: GitHub Actions workflow for automatic Android APK compilation (`Build Release APK` pipeline)

---

## ✨ Features

### 📊 Luminous Dashboard
- **Metabolic Rings**: Dynamic visual progress tracking of calorie goals, protein, carbs, fat, and hydration.
- **Dynamic Metrics Editor**: Tapping "Edit" on the main card launches a blur-background metrics panel to override daily calories, macronutrient targets, and water intake.
- **Embedded Daily History**: Inline log tracker showing every item logged on the selected day, with immediate editing/removal options.

### 🔍 Zivo Vision Lens (V4 AI Decision Engine)
- **Unified Barcode & Visual Scanner**: Scan any food, supplement, or skincare product via barcode, manual digits, or product photos.
- **Automated Classification**: Automatically detects whether the scanned product is a food, supplement, or skincare item without manual user input.
- **Database & AI Pipeline**: Queries public APIs (OpenFoodFacts/OpenBeautyFacts) for metadata, then funnels ingredients to Gemini 2.5 Flash Cloud Functions for a premium WHOOP/Apple Health-style evaluation.
- **Visual Grades & Verdicts**: Instantly displays a health grade (A–E) and clear, direct verdict on real-world impact.
- **Responsive Insights Grid**: Bulleted key highlights detailing palm oil, sugar spikes, additives, or acne triggers, fully responsive on all screen sizes.
- **Healthier Alternatives & Store Links**: Recommends 3 healthier category-matched alternatives. Tapping an alternative dynamically updates purchase buttons linked to services like Blinkit, Zepto, Swiggy Instamart, Amazon, Myntra, and Nykaa with brand favicons.

### 🍎 Food Journaling
- **AI Photo Scan**: Upload or take a picture of a meal for automated calorie and macronutrient parsing. Includes disclaimer notices and manual overrides.
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
- Node.js `^24.0.0` (for Cloud Functions)
- Firebase CLI (`npm install -g firebase-tools`)
- Java 17+ (configured via JDK)

### Local Configuration

1. **Initialize Flutter dependencies:**
   ```bash
   flutter pub get
   ```

2. **Configure Firebase & Cloud Functions:**
   * Place a valid `google-services.json` in `android/app/`.
   * Configure your local env secrets or deploy functions with the `GEMINI_API_KEY` secret configured in GCP Secret Manager.
   * Build and lint functions:
     ```bash
     cd functions
     npm install
     npm run build
     npm run lint
     ```

3. **Deploy Cloud Functions:**
   ```bash
   npx firebase deploy --only functions
   ```

4. **Run the Application:**
   * **For Web (Normal Chrome Browser):**
     To serve locally and view in your standard Chrome browser without test automation debug profiles:
     ```bash
     flutter run -d web-server --web-port=8080 --web-hostname=127.0.0.1
     ```
     Once running, open your regular Chrome browser and navigate to:
     [http://127.0.0.1:8080](http://127.0.0.1:8080)

   * **For Web (Flutter Debug Chrome):**
     ```bash
     flutter run -d chrome
     ```

   * **For Android (Native):**
     ```bash
     flutter run -d android
     ```

### CI/CD Workflow
- The project includes a pre-configured GitHub Action workflow in `.github/workflows/build_apk.yml` that compiles the release package on push or pull requests to the `main` branch.
- Cross-platform helper wrappers are used (e.g. `web_notification_helper.dart`) to prevent compilation errors of web-specific elements (`dart:js`) on native targets.
