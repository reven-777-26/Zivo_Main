import 'package:hive/hive.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 0)
class UserProfile extends HiveObject {
  @HiveField(0)
  final String goal; // 'lose', 'gain', 'maintain'

  @HiveField(1)
  final int age;

  @HiveField(2)
  final double weight; // in kg

  @HiveField(3)
  final double height; // in cm

  @HiveField(4)
  final String activityLevel; // 'sedentary', 'light', 'moderate', 'very'

  @HiveField(5)
  final int calorieGoal;

  @HiveField(6)
  final int proteinGoal;

  @HiveField(7)
  final int waterGoal;

  @HiveField(8)
  final String gender; // 'male', 'female', 'other'

  @HiveField(9)
  final String skinType; // 'Dry', 'Oily', 'Sensitive', 'Acne', 'Normal'

  UserProfile({
    required this.goal,
    required this.age,
    required this.weight,
    required this.height,
    required this.activityLevel,
    required this.calorieGoal,
    required this.proteinGoal,
    required this.waterGoal,
    this.gender = 'male',
    this.skinType = 'Normal',
  });

  UserProfile copyWith({
    String? goal,
    int? age,
    double? weight,
    double? height,
    String? activityLevel,
    int? calorieGoal,
    int? proteinGoal,
    int? waterGoal,
    String? gender,
    String? skinType,
  }) {
    return UserProfile(
      goal: goal ?? this.goal,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      activityLevel: activityLevel ?? this.activityLevel,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      waterGoal: waterGoal ?? this.waterGoal,
      gender: gender ?? this.gender,
      skinType: skinType ?? this.skinType,
    );
  }
}
