class HealthMath {
  /// Calculates BMR using the Mifflin-St Jeor formula with a gender-specific offset (Male: +5, Female: -161).
  static double calculateBMR({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required String gender,
  }) {
    final cleanGender = gender.trim().toLowerCase();
    if (cleanGender == 'female') {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears) - 161;
    } else if (cleanGender == 'male') {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears) + 5;
    }
    // Fallback / Gender-neutral average
    return (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears) - 78;
  }

  /// Calculates TDEE by applying activity multipliers to BMR.
  static double calculateTDEE({
    required double bmr,
    required String activityLevel,
  }) {
    double multiplier;
    switch (activityLevel.toLowerCase()) {
      case 'sedentary':
        multiplier = 1.2;
        break;
      case 'light':
      case 'lightly active':
        multiplier = 1.375;
        break;
      case 'moderate':
      case 'moderately active':
        multiplier = 1.55;
        break;
      case 'very':
      case 'very active':
        multiplier = 1.725;
        break;
      default:
        multiplier = 1.2;
    }
    return bmr * multiplier;
  }

  /// Calculates the calorie, protein, and water targets based on onboarding data.
  static HealthTargets calculateTargets({
    required String goal,
    required int age,
    required double weight,
    required double height,
    required String activityLevel,
    required String gender,
  }) {
    final bmr = calculateBMR(weightKg: weight, heightCm: height, ageYears: age, gender: gender);
    final tdee = calculateTDEE(bmr: bmr, activityLevel: activityLevel);

    int calorieGoal;
    double proteinMultiplier;

    switch (goal.toLowerCase()) {
      case 'lose':
      case 'lose weight':
        calorieGoal = (tdee - 500).round();
        if (calorieGoal < 1200) calorieGoal = 1200; // Safe minimum limit
        proteinMultiplier = 2.0;
        break;
      case 'gain':
      case 'gain muscle':
        calorieGoal = (tdee + 300).round();
        proteinMultiplier = 2.2;
        break;
      case 'maintain':
      case 'maintain weight':
      default:
        calorieGoal = tdee.round();
        proteinMultiplier = 1.8;
        break;
    }

    final proteinGoal = (weight * proteinMultiplier).round();

    // 25% of calories from healthy fats (1g fat = 9 calories)
    final fatGoal = ((calorieGoal * 0.25) / 9).round();

    // Carbs fill the remainder of the calorie goal (1g carb = 4 calories)
    final remainingCalories = calorieGoal - (proteinGoal * 4) - (fatGoal * 9);
    final carbGoal = (remainingCalories / 4).round();

    // Water target: 35ml per kg of bodyweight, with a minimum of 2000ml
    int waterGoal = (weight * 35).round();
    if (waterGoal < 2000) waterGoal = 2000;

    return HealthTargets(
      bmr: bmr.round(),
      tdee: tdee.round(),
      calorieGoal: calorieGoal,
      proteinGoal: proteinGoal,
      carbGoal: carbGoal,
      fatGoal: fatGoal,
      waterGoal: waterGoal,
    );
  }
}

class HealthTargets {
  final int bmr;
  final int tdee;
  final int calorieGoal;
  final int proteinGoal;
  final int carbGoal;
  final int fatGoal;
  final int waterGoal;

  HealthTargets({
    required this.bmr,
    required this.tdee,
    required this.calorieGoal,
    required this.proteinGoal,
    required this.carbGoal,
    required this.fatGoal,
    required this.waterGoal,
  });
}
