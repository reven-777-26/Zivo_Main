import 'dart:math';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

enum CalorieTier {
  significantUnder,
  moderateUnder,
  mildUnder,
  perfect,
  mildOver,
  moderateOver,
  significantOver,
}

enum HydrationTier {
  significantUnder,
  moderateUnder,
  mildUnder,
  onTarget,
  over,
}

enum WorkoutTier {
  lowVolume,
  moderateVolume,
  highVolumeBalanced,
  highVolumeNoRest,
}

enum InsightSeverity {
  good,
  warning,
  alert,
}

class InsightCard {
  final String title;
  final String body;
  final String iconType; // 'calorie' | 'hydration' | 'workout' | 'correlation'
  final bool needsAttention;
  final InsightSeverity severity;

  InsightCard({
    required this.title,
    required this.body,
    required this.iconType,
    required this.needsAttention,
    required this.severity,
  });
}

class InsightEngine {
  static CalorieTier getCalorieTier(double actual, double target) {
    if (target <= 0) return CalorieTier.perfect;
    final deltaPct = (actual - target) / target * 100;
    final absDelta = (actual - target).abs();
    final perfectThreshold = min(200.0, target * 0.07);

    if (absDelta <= perfectThreshold) {
      return CalorieTier.perfect;
    } else if (deltaPct < -25) {
      return CalorieTier.significantUnder;
    } else if (deltaPct >= -25 && deltaPct < -10) {
      return CalorieTier.moderateUnder;
    } else if (actual < target) {
      return CalorieTier.mildUnder;
    } else if (deltaPct > 25) {
      return CalorieTier.significantOver;
    } else if (deltaPct > 10 && deltaPct <= 25) {
      return CalorieTier.moderateOver;
    } else {
      return CalorieTier.mildOver;
    }
  }

  static HydrationTier getHydrationTier(double actualL, double targetL) {
    if (targetL <= 0) return HydrationTier.onTarget;
    if (actualL > targetL) {
      return HydrationTier.over;
    } else if (actualL == targetL) {
      return HydrationTier.onTarget;
    }
    final shortPct = (targetL - actualL) / targetL * 100;
    if (shortPct > 40) {
      return HydrationTier.significantUnder;
    } else if (shortPct > 15) {
      return HydrationTier.moderateUnder;
    } else {
      return HydrationTier.mildUnder;
    }
  }

  static WorkoutTier getWorkoutTier(int sessionsThisWeek, int restDaysThisWeek) {
    if (sessionsThisWeek <= 1) {
      return WorkoutTier.lowVolume;
    } else if (sessionsThisWeek <= 3) {
      return WorkoutTier.moderateVolume;
    } else if (restDaysThisWeek >= 1) {
      return WorkoutTier.highVolumeBalanced;
    } else {
      return WorkoutTier.highVolumeNoRest;
    }
  }

  static int getAndUpdateStreak(String metricKey, String currentTier, String todayStr, Box box) {
    final lastDate = box.get('${metricKey}_last_date') as String?;
    final lastTier = box.get('${metricKey}_last_tier') as String?;
    int currentStreak = box.get('${metricKey}_streak') as int? ?? 1;

    if (lastDate == todayStr) {
      if (lastTier != currentTier) {
        box.put('${metricKey}_last_tier', currentTier);
      }
      return currentStreak;
    }

    bool isYesterday = false;
    if (lastDate != null) {
      try {
        final lastParsed = DateFormat('yyyy-MM-dd').parse(lastDate);
        final todayParsed = DateFormat('yyyy-MM-dd').parse(todayStr);
        if (todayParsed.difference(lastParsed).inDays == 1) {
          isYesterday = true;
        }
      } catch (_) {}
    }

    if (isYesterday && lastTier == currentTier) {
      currentStreak += 1;
    } else {
      currentStreak = 1;
    }

    box.put('${metricKey}_last_date', todayStr);
    box.put('${metricKey}_last_tier', currentTier);
    box.put('${metricKey}_streak', currentStreak);
    return currentStreak;
  }

  static int getNextTemplateIndex(String bankKey, int bankSize, Box box) {
    if (bankSize <= 1) return 0;
    final lastIndex = box.get('last_template_index_$bankKey') as int?;
    final random = Random();
    int newIndex;
    do {
      newIndex = random.nextInt(bankSize);
    } while (lastIndex != null && newIndex == lastIndex);
    box.put('last_template_index_$bankKey', newIndex);
    return newIndex;
  }

  static String fillSlots(String template, Map<String, dynamic> values) {
    var result = template;
    values.forEach((key, val) {
      String replacement;
      if (val is double || val is num) {
        if (key == 'deltaL' || key == 'actualL' || key == 'targetL') {
          replacement = val.toDouble().toStringAsFixed(1);
        } else if (key == 'delta' || key == 'actual' || key == 'target' || key == 'deltaPct') {
          replacement = val.toDouble().round().toString();
        } else {
          replacement = val.toString();
        }
      } else {
        replacement = val.toString();
      }
      result = result.replaceAll('{$key}', replacement);
    });
    return result;
  }

  static List<InsightCard> generateDailyInsights({
    required double actualKcal,
    required double targetKcal,
    required String goalType, // 'cut' | 'bulk' | 'maintain'
    required double actualWaterL,
    required double targetWaterL,
    required int workoutSessionsThisWeek,
    required int restDaysThisWeek,
  }) {
    final box = Hive.box('insight_tracking');
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 1. Calculate tiers
    final calorieTier = getCalorieTier(actualKcal, targetKcal);
    final hydrationTier = getHydrationTier(actualWaterL, targetWaterL);
    final workoutTier = getWorkoutTier(workoutSessionsThisWeek, restDaysThisWeek);

    final calTierStr = calorieTier.toString().split('.').last;
    final hydTierStr = hydrationTier.toString().split('.').last;
    final workTierStr = workoutTier.toString().split('.').last;

    // 2. Update streaks
    final calStreak = getAndUpdateStreak('calorie', calTierStr, todayStr, box);
    final hydStreak = getAndUpdateStreak('hydration', hydTierStr, todayStr, box);
    final workStreak = getAndUpdateStreak('workout', workTierStr, todayStr, box);

    // 3. Check Correlation flags
    bool hasHighTrainingLowFuel = (workoutTier == WorkoutTier.highVolumeBalanced || workoutTier == WorkoutTier.highVolumeNoRest) &&
        (calorieTier == CalorieTier.significantUnder || calorieTier == CalorieTier.moderateUnder);

    bool hasLowHydrationHighTraining = (workoutTier == WorkoutTier.highVolumeBalanced || workoutTier == WorkoutTier.highVolumeNoRest) &&
        (hydrationTier == HydrationTier.significantUnder || hydrationTier == HydrationTier.moderateUnder);

    bool hasCutOverTargetStreak = goalType == 'cut' &&
        (calorieTier == CalorieTier.significantOver || calorieTier == CalorieTier.moderateOver) &&
        calStreak >= 2;

    bool hasBulkUnderTarget = goalType == 'bulk' &&
        (calorieTier == CalorieTier.significantUnder || calorieTier == CalorieTier.moderateUnder);

    // perfectWeekStreak check: all 3 metrics in good tier for 5+ days
    bool meetsPerfectWeekToday = (calorieTier == CalorieTier.perfect || calorieTier == CalorieTier.mildUnder || calorieTier == CalorieTier.mildOver) &&
        (hydrationTier == HydrationTier.onTarget) &&
        (workoutTier != WorkoutTier.lowVolume);

    int perfectWeekStreak = box.get('perfect_week_streak') as int? ?? 0;
    final lastPerfDate = box.get('perfect_week_last_date') as String?;

    if (lastPerfDate != todayStr) {
      bool isYesterday = false;
      if (lastPerfDate != null) {
        try {
          final lastParsed = DateFormat('yyyy-MM-dd').parse(lastPerfDate);
          final todayParsed = DateFormat('yyyy-MM-dd').parse(todayStr);
          if (todayParsed.difference(lastParsed).inDays == 1) {
            isYesterday = true;
          }
        } catch (_) {}
      }

      if (meetsPerfectWeekToday) {
        if (isYesterday || lastPerfDate == null) {
          perfectWeekStreak += 1;
        } else {
          perfectWeekStreak = 1;
        }
      } else {
        perfectWeekStreak = 0;
      }
      box.put('perfect_week_last_date', todayStr);
      box.put('perfect_week_streak', perfectWeekStreak);
    }

    bool hasPerfectWeekStreak = perfectWeekStreak >= 5;

    // Determine if any flag matched (Priority: highTrainingLowFuel, lowHydrationHighTraining, cutOverTargetStreak, bulkUnderTarget, perfectWeekStreak)
    String? matchedFlag;
    if (hasHighTrainingLowFuel) {
      matchedFlag = 'highTrainingLowFuel';
    } else if (hasLowHydrationHighTraining) {
      matchedFlag = 'lowHydrationHighTraining';
    } else if (hasCutOverTargetStreak) {
      matchedFlag = 'cutOverTargetStreak';
    } else if (hasBulkUnderTarget) {
      matchedFlag = 'bulkUnderTarget';
    } else if (hasPerfectWeekStreak) {
      matchedFlag = 'perfectWeekStreak';
    }

    final List<InsightCard> cards = [];

    // Helper slots
    final double calDelta = (actualKcal - targetKcal).abs();
    final double calDeltaPct = targetKcal > 0 ? (calDelta / targetKcal * 100) : 0.0;
    final double hydDelta = (actualWaterL - targetWaterL).abs();

    final Map<String, dynamic> calorieSlots = {
      'actual': actualKcal,
      'target': targetKcal,
      'delta': calDelta,
      'deltaPct': calDeltaPct,
      'streak': calStreak,
      'plural': calStreak != 1 ? 's' : '',
    };

    final Map<String, dynamic> hydrationSlots = {
      'actualL': actualWaterL,
      'targetL': targetWaterL,
      'deltaL': hydDelta,
      'streak': hydStreak,
      'plural': hydStreak != 1 ? 's' : '',
    };

    final Map<String, dynamic> workoutSlots = {
      'count': workoutSessionsThisWeek,
      'restDays': restDaysThisWeek,
      'streak': workStreak,
      'plural': workoutSessionsThisWeek != 1 ? 's' : '',
    };

    // If correlation flag matched, generate it
    InsightCard? correlationCard;
    bool skipCalorie = false;
    bool skipHydration = false;
    bool skipWorkout = false;

    if (matchedFlag != null) {
      final bankKey = 'correlation_$matchedFlag';
      final templatesList = InsightTemplates.templates[bankKey] ?? [];
      if (templatesList.isNotEmpty) {
        final idx = getNextTemplateIndex(bankKey, templatesList.length, box);
        final rawTemplate = templatesList[idx];

        // Combine slots for correlation
        final combinedSlots = <String, dynamic>{}
          ..addAll(calorieSlots)
          ..addAll(hydrationSlots)
          ..addAll(workoutSlots);

        final filledText = fillSlots(rawTemplate, combinedSlots);
        final corrSeverity = matchedFlag == 'perfectWeekStreak' ? InsightSeverity.good : InsightSeverity.alert;

        correlationCard = InsightCard(
          title: matchedFlag == 'perfectWeekStreak' ? 'Elite Consistency' : 'Aura Health Warning',
          body: filledText,
          iconType: 'correlation',
          needsAttention: matchedFlag != 'perfectWeekStreak',
          severity: corrSeverity,
        );
      }

      if (matchedFlag == 'highTrainingLowFuel') {
        skipCalorie = true;
        skipWorkout = true;
      } else if (matchedFlag == 'lowHydrationHighTraining') {
        skipHydration = true;
        skipWorkout = true;
      } else if (matchedFlag == 'cutOverTargetStreak') {
        skipCalorie = true;
      } else if (matchedFlag == 'bulkUnderTarget') {
        skipCalorie = true;
      } else if (matchedFlag == 'perfectWeekStreak') {
        skipCalorie = true;
        skipHydration = true;
        skipWorkout = true;
      }
    }

    if (correlationCard != null) {
      cards.add(correlationCard);
    }

    // 4. Generate Calorie Card if not skipped
    if (!skipCalorie) {
      final bankKey = 'calorie_${goalType}_$calTierStr';
      final templatesList = InsightTemplates.templates[bankKey] ?? [];
      if (templatesList.isNotEmpty) {
        final idx = getNextTemplateIndex(bankKey, templatesList.length, box);
        final rawTemplate = templatesList[idx];
        final filledText = fillSlots(rawTemplate, calorieSlots);

        final attention = calorieTier != CalorieTier.perfect;
        
        InsightSeverity calSeverity;
        if (calorieTier == CalorieTier.perfect) {
          calSeverity = InsightSeverity.good;
        } else if (calorieTier == CalorieTier.mildUnder || calorieTier == CalorieTier.mildOver) {
          calSeverity = InsightSeverity.warning;
        } else {
          calSeverity = InsightSeverity.alert;
        }

        cards.add(InsightCard(
          title: 'Metabolic Balance',
          body: filledText,
          iconType: 'calorie',
          needsAttention: attention,
          severity: calSeverity,
        ));
      }
    }

    // 5. Generate Hydration Card if not skipped
    if (!skipHydration) {
      final bankKey = 'hydration_$hydTierStr';
      final templatesList = InsightTemplates.templates[bankKey] ?? [];
      if (templatesList.isNotEmpty) {
        final idx = getNextTemplateIndex(bankKey, templatesList.length, box);
        final rawTemplate = templatesList[idx];
        final filledText = fillSlots(rawTemplate, hydrationSlots);

        final attention = hydrationTier != HydrationTier.onTarget;

        InsightSeverity hydSeverity;
        if (hydrationTier == HydrationTier.onTarget || hydrationTier == HydrationTier.over) {
          hydSeverity = InsightSeverity.good;
        } else if (hydrationTier == HydrationTier.mildUnder) {
          hydSeverity = InsightSeverity.warning;
        } else {
          hydSeverity = InsightSeverity.alert;
        }

        cards.add(InsightCard(
          title: 'Hydration Consistency',
          body: filledText,
          iconType: 'hydration',
          needsAttention: attention,
          severity: hydSeverity,
        ));
      }
    }

    // 6. Generate Workout Card if not skipped
    if (!skipWorkout) {
      final bankKey = 'workout_$workTierStr';
      final templatesList = InsightTemplates.templates[bankKey] ?? [];
      if (templatesList.isNotEmpty) {
        final idx = getNextTemplateIndex(bankKey, templatesList.length, box);
        final rawTemplate = templatesList[idx];
        final filledText = fillSlots(rawTemplate, workoutSlots);

        final attention = workoutTier != WorkoutTier.moderateVolume && workoutTier != WorkoutTier.highVolumeBalanced;

        InsightSeverity workSeverity;
        if (workoutTier == WorkoutTier.moderateVolume || workoutTier == WorkoutTier.highVolumeBalanced) {
          workSeverity = InsightSeverity.good;
        } else if (workoutTier == WorkoutTier.lowVolume) {
          workSeverity = InsightSeverity.warning;
        } else {
          workSeverity = InsightSeverity.alert;
        }

        cards.add(InsightCard(
          title: 'Active Recovery',
          body: filledText,
          iconType: 'workout',
          needsAttention: attention,
          severity: workSeverity,
        ));
      }
    }

    return cards;
  }
}

class InsightTemplates {
  static const Map<String, List<String>> templates = {
    // calorie_cut
    'calorie_cut_significantUnder': [
      "{delta}kcal under target, which is a big gap for day {streak}. Even on a cut, eat closer to target to protect muscle and energy.",
      "You're significantly under at {actual}kcal vs {target}kcal target. This isn't lean cutting, it's just under-fueling, so close the gap a bit.",
      "{deltaPct}% under target today. A cut should be a moderate deficit, not this, so add a meal or snack.",
      "Big shortfall today of {delta}kcal. With {streak} day{plural} of this, your body starts holding onto fat instead of burning it."
    ],
    'calorie_cut_moderateUnder': [
      "{delta}kcal under target today, with {streak} day{plural} running. You're cutting, so this tracks. Keep protein steady to hold onto muscle.",
      "Logged {actual}kcal vs your {target}kcal target. With {streak} day{plural} in a deficit zone, this is solid for a cut. Just don't let protein slip.",
      "{deltaPct}% under target on day {streak} of this trend. Expected during a cut, so prioritize protein at your next meal.",
      "You're {delta}kcal light today. With {streak} day{plural} like this, your cut is on track. Just watch muscle retention."
    ],
    'calorie_cut_mildUnder': [
      "{actual}kcal logged, {delta}kcal under target. Right where a cut should sit, nothing to fix here.",
      "Small deficit today at {delta}kcal under. This is exactly the zone for sustainable fat loss.",
      "{deltaPct}% under target, a healthy pace for a cut. Keep this consistency going."
    ],
    'calorie_cut_perfect': [
      "{actual}kcal, dead on target. On day {streak} of hitting this range, your cut is dialed in.",
      "Right on your {target}kcal target today. This kind of consistency is what actually moves the needle.",
      "Perfect hit at {actual}kcal. With {streak} day{plural} in this zone, your tracking discipline is showing."
    ],
    'calorie_cut_mildOver': [
      "{delta}kcal over target today. Not a big deal once in a while, but watch it if it repeats.",
      "Slightly over at {actual}kcal vs {target}kcal. One day won't move a cut, so stay consistent tomorrow."
    ],
    'calorie_cut_moderateOver': [
      "{delta}kcal over target on day {streak} of this trend. Cuts stall when this becomes a pattern, so tighten up tomorrow.",
      "{deltaPct}% over today. Check if it's calorie-dense foods sneaking in rather than portion size."
    ],
    'calorie_cut_significantOver': [
      "{delta}kcal over target, showing a real surplus today. This single day can offset 2 to 3 good ones on a cut.",
      "Big overshoot at {actual}kcal vs {target}kcal target. Worth looking back at what drove it today."
    ],

    // calorie_bulk
    'calorie_bulk_significantUnder': [
      "{delta}kcal under target, way short for a bulk. You can't build without the surplus, so add more food today.",
      "{actual}kcal logged vs {target}kcal needed. This kind of gap on day {streak} stalls muscle gain completely."
    ],
    'calorie_bulk_moderateUnder': [
      "{delta}kcal under target. On a bulk, this is a real problem. Try adding a calorie-dense snack.",
      "{deltaPct}% under target, with {streak} day{plural} now. Your bulk needs a consistent surplus, not just protein."
    ],
    'calorie_bulk_mildUnder': [
      "{delta}kcal under target. Close, but a bulk needs you slightly over, not under. Add a small snack.",
      "Just under target today at {actual}kcal. Push a little harder to stay in true surplus."
    ],
    'calorie_bulk_perfect': [
      "{actual}kcal, right in your bulk target zone. Day {streak} of consistent fueling is how mass gets built.",
      "Spot on at {target}kcal. Keep pairing this with your training and the gains will show."
    ],
    'calorie_bulk_mildOver': [
      "{delta}kcal over target, which is fine for a bulk. Slightly more surplus just speeds things along.",
      "Over by {delta}kcal today. On a bulk this is a non-issue, your body will use it."
    ],
    'calorie_bulk_moderateOver': [
      "{delta}kcal over target. Good for a bulk, just keep an eye on whether it's quality or junk calories.",
      "{deltaPct}% over today, fine for mass gain. Just don't let it drift into all-junk surplus."
    ],
    'calorie_bulk_significantOver': [
      "{delta}kcal over, a big surplus today. Even on a bulk, this pace adds fat faster than muscle.",
      "{actual}kcal vs {target}kcal target. Worth moderating tomorrow so gains stay lean."
    ],

    // calorie_maintain
    'calorie_maintain_significantUnder': [
      "{delta}kcal under target, a noticeable gap for maintenance. Make sure you're eating enough to sustain energy.",
      "{actual}kcal today, well under your {target}kcal target. Add a meal back in to stay balanced."
    ],
    'calorie_maintain_moderateUnder': [
      "{delta}kcal under target on day {streak} of this pattern. For maintenance, try closing this gap a bit.",
      "{deltaPct}% under today. Fine occasionally, but track if this becomes a weekly pattern."
    ],
    'calorie_maintain_mildUnder': [
      "{actual}kcal, close to your {target}kcal maintenance target. Nicely balanced day.",
      "Right around target at {actual}kcal. This is exactly the consistency maintenance is built on."
    ],
    'calorie_maintain_perfect': [
      "{actual}kcal, close to your {target}kcal maintenance target. Nicely balanced day.",
      "Right around target at {actual}kcal. This is exactly the consistency maintenance is built on."
    ],
    'calorie_maintain_mildOver': [
      "{delta}kcal over target today, well within normal day-to-day variation for maintenance.",
      "Slightly over at {actual}kcal. Nothing to worry about for a single day."
    ],
    'calorie_maintain_moderateOver': [
      "{delta}kcal over target, with {streak} day{plural} now. Worth checking what's driving the surplus before it adds up.",
      "{deltaPct}% over today. For maintenance, a few days like this can start shifting your weight trend."
    ],
    'calorie_maintain_significantOver': [
      "{delta}kcal over target, with {streak} day{plural} now. Worth checking what's driving the surplus before it adds up.",
      "{deltaPct}% over today. For maintenance, a few days like this can start shifting your weight trend."
    ],

    // hydration
    'hydration_significantUnder': [
      "Only {actualL}L today, which is {deltaL}L short of your {targetL}L goal. That is a big gap, so keep a bottle at your desk as a reminder.",
      "{actualL}L logged vs {targetL}L target, meaning you are significantly behind. Try front-loading water earlier in the day."
    ],
    'hydration_moderateUnder': [
      "{actualL}L today, which is {deltaL}L short of your {targetL}L goal. Try adding 250ml every 2 hours to close the gap.",
      "Hydration is at {actualL}L vs {targetL}L target. On day {streak} below goal, set a reminder for after lunch and dinner.",
      "{deltaL}L behind your hydration target today. A glass with each meal usually covers most of this gap."
    ],
    'hydration_mildUnder': [
      "{actualL}L today, just {deltaL}L under your {targetL}L goal. One more glass tonight closes it.",
      "Close to target at {actualL}L. A small top-up before bed gets you there."
    ],
    'hydration_onTarget': [
      "{actualL}L logged, right at your {targetL}L goal. This is day {streak} of solid hydration.",
      "Hydration goal hit at {actualL}L. This consistency helps recovery and energy more than people realize."
    ],
    'hydration_over': [
      "{actualL}L today, above your {targetL}L target. Good consistency, no need to push further."
    ],

    // workout
    'workout_lowVolume': [
      "{count} session{plural} logged this week. Even one more would meaningfully move your weekly progress.",
      "Only {count} workout{plural} so far this week, so try to get one more in before the week resets."
    ],
    'workout_moderateVolume': [
      "{count} session{plural} logged this week, solid pace. Keep stacking consistency over intensity.",
      "{count} workout{plural} this week, nice rhythm. Your body's adapting well at this frequency."
    ],
    'workout_highVolumeBalanced': [
      "{count} session{plural} logged this week. Keep stacking physical progression, your consistency is showing.",
      "{count} workout{plural} this week with rest days in place. This is a strong, sustainable pace."
    ],
    'workout_highVolumeNoRest': [
      "{count} session{plural} logged with no rest day yet this week. Consider a recovery day, as that is where the actual gains lock in.",
      "{count} workout{plural} back to back. Your muscles grow during rest, not just training, so build in a day off.",
      "Strong volume at {count} session{plural}, but zero rest days. Push too long without recovery and performance starts to dip."
    ],

    // correlation
    'correlation_highTrainingLowFuel': [
      "{count} workout{plural} this week but averaging {delta}kcal under target. Your body needs more fuel to recover from that volume.",
      "Training hard with {count} session{plural} while running a {delta}kcal deficit. This combo risks muscle loss more than fat loss, so eat a bit more.",
      "High training, low fuel: {count} session{plural} vs {delta}kcal under target. Add a post-workout snack to close the gap."
    ],
    'correlation_lowHydrationHighTraining': [
      "{count} workout{plural} this week but hydration is {deltaL}L under goal. Recovery and performance take a hit without enough water.",
      "Training volume is high but you're {deltaL}L short on water. Dehydration during heavy training weeks slows recovery noticeably."
    ],
    'correlation_bulkUnderTarget': [
      "You're trying to bulk but running {delta}kcal under target. Without a surplus, training volume alone won't add mass."
    ],
    'correlation_cutOverTargetStreak': [
      "{streak} day{plural} over target now while cutting, so it is worth reviewing what's driving the surplus before it stalls progress.",
      "Cut's been off-track for {streak} day{plural}, averaging {delta}kcal over. A reset day with simpler, lower-density meals can help."
    ],
    'correlation_perfectWeekStreak': [
      "5+ day{plural} of hitting calorie, hydration, and training targets together. This is the kind of week that actually compounds.",
      "Everything is lined up this week, with fueling, hydration, and training all on point. Days like this add up fast."
    ]
  };
}
