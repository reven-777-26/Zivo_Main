class WorkoutSession {
  final String id;
  final String date;
  final List<ExerciseLog> exercises;
  final int durationSeconds;
  final String notes;

  WorkoutSession({
    required this.id,
    required this.date,
    required this.exercises,
    required this.durationSeconds,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'durationSeconds': durationSeconds,
    'notes': notes,
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    id: json['id'] ?? '',
    date: json['date'] ?? '',
    exercises:
        (json['exercises'] as List?)
            ?.map((e) => ExerciseLog.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [],
    durationSeconds: json['durationSeconds'] ?? 0,
    notes: json['notes'] ?? '',
  );
}

class ExerciseLog {
  final String name;
  final String category;
  final List<ExerciseSet> sets;

  ExerciseLog({required this.name, required this.category, required this.sets});

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'sets': sets.map((e) => e.toJson()).toList(),
  };

  factory ExerciseLog.fromJson(Map<String, dynamic> json) => ExerciseLog(
    name: json['name'] ?? '',
    category: json['category'] ?? '',
    sets:
        (json['sets'] as List?)
            ?.map((e) => ExerciseSet.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [],
  );
}

class ExerciseSet {
  final double weight;
  final int reps;
  final int durationSeconds;
  final bool isCompleted;

  ExerciseSet({
    required this.weight,
    required this.reps,
    this.durationSeconds = 0,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'weight': weight,
    'reps': reps,
    'durationSeconds': durationSeconds,
    'isCompleted': isCompleted,
  };

  factory ExerciseSet.fromJson(Map<String, dynamic> json) => ExerciseSet(
    weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
    reps: json['reps'] ?? 0,
    durationSeconds: json['durationSeconds'] ?? 0,
    isCompleted: json['isCompleted'] ?? false,
  );
}
