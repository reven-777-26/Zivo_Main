import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/workout_log.dart';
import '../../services/state_providers.dart';
import '../../services/storage_service.dart';
import '../../utils/image_picker_helper.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _DashboardTimer {
  Timer? _timer;
  final VoidCallback onTick;

  _DashboardTimer({required this.onTick});

  void start() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      onTick();
    });
  }

  void stop() {
    _timer?.cancel();
  }
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  int _elapsedSeconds = 0;
  _DashboardTimer? _gymTimer;
  final _searchController = TextEditingController();
  final _customExerciseController = TextEditingController();
  final _notesController = TextEditingController();
  final Set<String> _expandedDates = {};
  bool _showAllHistoryDates = false;
  int _activeWorkoutTab = 0;
  String? _selectedBeforeDate;
  String? _selectedAfterDate;
  double _splitPercentage = 0.5;


  // Mock Gym Exercises Library (FitNotes categories)
  final List<Map<String, String>> _exerciseLibrary = [
    {'name': 'Bench Press', 'category': 'Chest'},
    {'name': 'Incline Dumbbell Press', 'category': 'Chest'},
    {'name': 'Dumbbell Flys', 'category': 'Chest'},
    {'name': 'Cable Crossover', 'category': 'Chest'},
    {'name': 'Deadlift', 'category': 'Back'},
    {'name': 'Pullups', 'category': 'Back'},
    {'name': 'Lat Pulldown', 'category': 'Back'},
    {'name': 'Bent Over Row', 'category': 'Back'},
    {'name': 'Barbell Squat', 'category': 'Legs'},
    {'name': 'Leg Press', 'category': 'Legs'},
    {'name': 'Leg Extension', 'category': 'Legs'},
    {'name': 'Romanian Deadlift', 'category': 'Legs'},
    {'name': 'Overhead Barbell Press', 'category': 'Shoulders'},
    {'name': 'Dumbbell Lateral Raise', 'category': 'Shoulders'},
    {'name': 'Rear Delt Fly', 'category': 'Shoulders'},
    {'name': 'Bicep Barbell Curl', 'category': 'Arms'},
    {'name': 'Incline Dumbbell Curl', 'category': 'Arms'},
    {'name': 'Tricep Pushdown', 'category': 'Arms'},
    {'name': 'Skull Crusher', 'category': 'Arms'},
    {'name': 'Treadmill Running', 'category': 'Cardio'},
    {'name': 'Stationary Cycling', 'category': 'Cardio'},
    {'name': 'Elliptical Trainer', 'category': 'Cardio'},
  ];

  String _selectedCategoryFilter = 'All';

  @override
  void dispose() {
    _gymTimer?.stop();
    _searchController.dispose();
    _customExerciseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _gymTimer?.stop();
    _elapsedSeconds = 0;
    _gymTimer = _DashboardTimer(
      onTick: () {
        if (mounted) {
          setState(() {
            _elapsedSeconds++;
          });
        }
      },
    );
    _gymTimer?.start();
  }

  String _formatDuration(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showCancelWorkoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.obsidianBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.accentCoral),
            SizedBox(width: 8),
            Text(
              'Discard Session?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to exit and discard this active workout session? Your current progress will not be saved.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Resume',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _gymTimer?.stop();
              setState(() {
                _elapsedSeconds = 0;
              });
              ref.read(activeWorkoutProvider.notifier).cancelWorkout();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Workout session discarded'),
                  backgroundColor: AppTheme.accentCoral,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCoral,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Discard',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showAllPresetsSheet(BuildContext context) {
    final templates = StorageService.getWorkoutTemplates();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final String searchQuery = _searchController.text.toLowerCase();
            final filtered = templates.where((t) {
              final name = (t['name'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: AppTheme.obsidianBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                border: Border(
                  top: BorderSide(color: AppTheme.glassBorder, width: 1.5),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppTheme.bgGradient,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'All Workout Presets',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white),
                              onPressed: () => Navigator.pop(sheetContext),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Search bar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.glassBorder, width: 1.0),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Search presets...',
                              hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 18),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: (val) {
                              setSheetState(() {});
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Grid/List of presets
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No presets found.',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (sheetContext, idx) {
                                    final template = filtered[idx];
                                    final String name = template['name'] ?? 'Preset';
                                    final exercisesList = List.from(template['exercises'] ?? []);

                                    // Map Cover Images matching Stitch export definitions
                                    String coverImg = 'https://lh3.googleusercontent.com/aida-public/AB6AXuAv88umiT4-zyXku24m6rCn_7MsRbE5r4-3LuHx27fajtASoOzUnnMYX1p-TCmsX20c-8jDePM8VuYliL6zjraF0EwQhf2SrVfZ8scHf45h5853T4-N0qwR7RJrmipfk4MBXczUS2gTnH8cwdrIUoyOZoOpKguNhWGbJ5f7moF_ByDIVb4Wiu5_IScdQzP5xw1KyXzep-VsaVa_QOn2Kr-w8tdMBpxTcWLxSA2bh_bDks_hZCg2z0VGzm3Dh6xzwR9vADpCMDVvPz0'; // default push
                                    Color tagBg = AppTheme.accentCyan.withOpacity(0.1);
                                    Color tagColor = AppTheme.accentCyan;
                                    String tagLabel = 'CHEST/TRI';

                                    if (name.toLowerCase().contains('pull')) {
                                      coverImg = 'https://lh3.googleusercontent.com/aida-public/AB6AXuA8Gl3X7nPoIbxCmF6eUCJv8vT122CItc_VzVnacZdFDYsgKn0KuhnC86aaCvcUDdEBa8kTyeNLUwCxkNyE8gdudzaugwFBJ6Pj4eRs2YAXKG4joPZNPi985mpAYemNwobD-fSQf_SBhCA5jlxpqYx-9ie1I_1Vl7UzeYCPlqxF5KF80fH2bA3Vo2Vte9IxqkDmLtgxj92Fsqqj55aQ9HqtiDU84GJ-77cHnGndz_2rER-0IvVduJCj9DJYl69oFZwcs5TaA-SN2VI';
                                      tagBg = AppTheme.accentOrange.withOpacity(0.1);
                                      tagColor = AppTheme.accentOrange;
                                      tagLabel = 'BACK/BI';
                                    } else if (name.toLowerCase().contains('leg')) {
                                      coverImg = 'https://lh3.googleusercontent.com/aida-public/AB6AXuDor9HYgo41CQACkt57Opwf-tLpxXZj7vGSZNwqcGAZfzew5vtF6170YQBcf0ey8SSkeyWA--IlFrOHnfZh8Ro38m8AgA8HgFu5vE9Fgn76_n0i6cOHMjH9sBzwTy-irH8H9VVjo7LOPHUWEXFVn7e6mEHV4ZfmbxUkJEcqDGZIoWmXWrh1eGwSg9de6K0KvNGAS_ZBmTBl0rH9586nvlozSnwIcAf7BGCMaXqcl7ksPIn2oQ4juNyAKrmXhWkIuSLaqptG5yXOcT0';
                                      tagBg = AppTheme.accentCyan.withOpacity(0.2);
                                      tagColor = AppTheme.accentCyan;
                                      tagLabel = 'QUADS/GLUTES';
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppTheme.glassBorder, width: 1),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Stack(
                                          children: [
                                            // Cover Image
                                            Positioned.fill(
                                              child: Image.network(
                                                coverImg,
                                                fit: BoxFit.cover,
                                                color: Colors.black.withOpacity(0.75),
                                                colorBlendMode: BlendMode.darken,
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Row(
                                                          children: [
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: Colors.white.withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: Text(
                                                                '${exercisesList.length} EX',
                                                                style: const TextStyle(
                                                                  color: AppTheme.textPrimary,
                                                                  fontSize: 8,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 6),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: tagBg,
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: Text(
                                                                tagLabel,
                                                                style: TextStyle(
                                                                  color: tagColor,
                                                                  fontSize: 8,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if (name != 'Push Day' &&
                                                          name != 'Pull Day' &&
                                                          name != 'Leg Day' &&
                                                          name != 'Full Body AI')
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons.delete_outline_rounded,
                                                            color: AppTheme.accentCoral,
                                                            size: 20,
                                                          ),
                                                          onPressed: () async {
                                                            await StorageService.deleteWorkoutTemplate(name);
                                                            setSheetState(() {});
                                                            setState(() {});
                                                          },
                                                        ),
                                                      const SizedBox(width: 4),
                                                      ElevatedButton(
                                                        onPressed: () {
                                                          Navigator.pop(sheetContext);
                                                          final exData = (template['exercises'] as List)
                                                              .map((e) => Map<String, String>.from(e))
                                                              .toList();
                                                          ref
                                                              .read(activeWorkoutProvider.notifier)
                                                              .startWorkoutWithExercises(exData);
                                                          _startTimer();
                                                          _notesController.clear();
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text('Started $name session!'),
                                                              backgroundColor: AppTheme.accentCyan,
                                                            ),
                                                          );
                                                        },
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: AppTheme.accentCyan,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        ),
                                                        child: const Text(
                                                          'Start',
                                                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeWorkout = ref.watch(activeWorkoutProvider);
    final history = ref.watch(workoutHistoryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Header title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (activeWorkout.isActive) ...[
                        GestureDetector(
                          onTap: () => _showCancelWorkoutDialog(context),
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.glassBackground,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.glassBorder, width: 1),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        activeWorkout.isActive
                            ? 'Active live Gym Log'
                            : 'Workout Tracker',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  if (activeWorkout.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCoral.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.timer_rounded,
                            color: AppTheme.accentCoral,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(_elapsedSeconds),
                            style: const TextStyle(
                              color: AppTheme.accentCoral,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: activeWorkout.isActive
                    ? _buildActiveWorkoutLogger(activeWorkout)
                    : _buildStartWorkoutPanel(history),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // VIEW: START WORKOUT PANEL (LIVE SESSION CLOSED)
  // ==========================================
  Widget _buildStartWorkoutPanel(List<WorkoutSession> history) {
    final templates = StorageService.getWorkoutTemplates();
    return Column(
      children: [
        // Tab selector row
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeWorkoutTab = 0),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: _activeWorkoutTab == 0
                        ? AppTheme.accentCyan.withOpacity(0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _activeWorkoutTab == 0
                          ? AppTheme.accentCyan
                          : AppTheme.glassBorder,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Workout Tracker',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _activeWorkoutTab == 0 ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeWorkoutTab = 1),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: _activeWorkoutTab == 1
                        ? AppTheme.accentPurple.withOpacity(0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _activeWorkoutTab == 1
                          ? AppTheme.accentPurple
                          : AppTheme.glassBorder,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Physique Analyzer',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _activeWorkoutTab == 1 ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _activeWorkoutTab == 0
              ? SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                // Gym Hero Section
                Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.glassBorder, width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuCJDIGUIFqw7p4oAiOPD3oeBE8Tl0LB6HXpD1rSuvwvF3FCUb230JcKUtq7n-sc7a9mPKLZRo-uW0wUz4n-Lvp2Vc7pFTVctvmJT_d7HyEw6oFLCCzX119vuQJJu6s1SbXxr5vazXnDdeV8geWscHEswfWQ8cBkJ_wc8m0q0Nal35yEIoMM6EUg2e7iWODi1Fh797PdHdIYXC-A8FIRM_9uwPFDpvGEhfCwGgaN2aOmtzQIzs4pe2QLeXGPR9huSaNE2Eb45JQPt9I',
                          fit: BoxFit.cover,
                          color: Colors.black.withOpacity(0.55),
                          colorBlendMode: BlendMode.darken,
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppTheme.obsidianBackground,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    height: 1.15,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Push Your\n',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    TextSpan(
                                      text: 'Limits Today',
                                      style: TextStyle(color: AppTheme.accentCyan),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Ready to beat your personal best? Track every rep and set with precision.',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: () {
                                  ref.read(activeWorkoutProvider.notifier).startWorkout();
                                  _startTimer();
                                  _notesController.clear();
                                },
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(9999),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.accentCyan.withOpacity(0.2),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Start Live Session',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Presets Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Workout Presets',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showAllPresetsSheet(context),
                      child: const Text(
                        'VIEW ALL',
                        style: TextStyle(
                          color: AppTheme.accentCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Bento Presets Grid
                if (templates.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No templates created yet.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: templates.length,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 240,
                      childAspectRatio: 1.25,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, idx) {
                      final template = templates[idx];
                      final String name = template['name'] ?? 'Preset';
                      final exercisesList = List.from(template['exercises'] ?? []);

                      // Map Cover Images matching Stitch export definitions
                      String coverImg = 'https://lh3.googleusercontent.com/aida-public/AB6AXuAv88umiT4-zyXku24m6rCn_7MsRbE5r4-3LuHx27fajtASoOzUnnMYX1p-TCmsX20c-8jDePM8VuYliL6zjraF0EwQhf2SrVfZ8scHf45h5853T4-N0qwR7RJrmipfk4MBXczUS2gTnH8cwdrIUoyOZoOpKguNhWGbJ5f7moF_ByDIVb4Wiu5_IScdQzP5xw1KyXzep-VsaVa_QOn2Kr-w8tdMBpxTcWLxSA2bh_bDks_hZCg2z0VGzm3Dh6xzwR9vADpCMDVvPz0'; // default push
                      Color tagBg = AppTheme.accentCyan.withOpacity(0.1);
                      Color tagColor = AppTheme.accentCyan;
                      String tagLabel = 'CHEST/TRI';

                      if (name.toLowerCase().contains('pull')) {
                        coverImg = 'https://lh3.googleusercontent.com/aida-public/AB6AXuA8Gl3X7nPoIbxCmF6eUCJv8vT122CItc_VzVnacZdFDYsgKn0KuhnC86aaCvcUDdEBa8kTyeNLUwCxkNyE8gdudzaugwFBJ6Pj4eRs2YAXKG4joPZNPi985mpAYemNwobD-fSQf_SBhCA5jlxpqYx-9ie1I_1Vl7UzeYCPlqxF5KF80fH2bA3Vo2Vte9IxqkDmLtgxj92Fsqqj55aQ9HqtiDU84GJ-77cHnGndz_2rER-0IvVduJCj9DJYl69oFZwcs5TaA-SN2VI';
                        tagBg = AppTheme.accentOrange.withOpacity(0.1);
                        tagColor = AppTheme.accentOrange;
                        tagLabel = 'BACK/BI';
                      } else if (name.toLowerCase().contains('leg')) {
                        coverImg = 'https://lh3.googleusercontent.com/aida-public/AB6AXuDor9HYgo41CQACkt57Opwf-tLpxXZj7vGSZNwqcGAZfzew5vtF6170YQBcf0ey8SSkeyWA--IlFrOHnfZh8Ro38m8AgA8HgFu5vE9Fgn76_n0i6cOHMjH9sBzwTy-irH8H9VVjo7LOPHUWEXFVn7e6mEHV4ZfmbxUkJEcqDGZIoWmXWrh1eGwSg9de6K0KvNGAS_ZBmTBl0rH9586nvlozSnwIcAf7BGCMaXqcl7ksPIn2oQ4juNyAKrmXhWkIuSLaqptG5yXOcT0';
                        tagBg = AppTheme.accentCyan.withOpacity(0.2);
                        tagColor = AppTheme.accentCyan;
                        tagLabel = 'QUADS/GLUTES';
                      }

                      return GestureDetector(
                        onTap: () {
                          final exData = (template['exercises'] as List)
                              .map((e) => Map<String, String>.from(e))
                              .toList();
                          ref
                              .read(activeWorkoutProvider.notifier)
                              .startWorkoutWithExercises(exData);
                          _startTimer();
                          _notesController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Started $name session!'),
                              backgroundColor: AppTheme.accentCyan,
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.glassBorder, width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  coverImg,
                                  fit: BoxFit.cover,
                                  color: Colors.black.withOpacity(0.65),
                                  colorBlendMode: BlendMode.darken,
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: tagColor.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              name.toLowerCase().contains('pull')
                                                  ? Icons.reorder_rounded
                                                  : name.toLowerCase().contains('leg')
                                                      ? Icons.airline_seat_legroom_extra_rounded
                                                      : Icons.fitness_center_rounded,
                                              color: tagColor,
                                              size: 18,
                                            ),
                                          ),
                                          if (name != 'Push Day' &&
                                              name != 'Pull Day' &&
                                              name != 'Leg Day' &&
                                              name != 'Full Body AI')
                                            GestureDetector(
                                              onTap: () async {
                                                await StorageService.deleteWorkoutTemplate(name);
                                                setState(() {});
                                              },
                                              child: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: AppTheme.accentCoral,
                                                size: 16,
                                              ),
                                            ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${exercisesList.length} EX',
                                                  style: const TextStyle(
                                                    color: AppTheme.textPrimary,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: tagBg,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  tagLabel,
                                                  style: TextStyle(
                                                    color: tagColor,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 32),

                // Recent History Header
                const Text(
                  'Recent History',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),

                if (history.isEmpty)
                  _buildEmptyHistoryCard()
                else ...[
                  Builder(
                    builder: (context) {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final List<DateTime> past15Days = List.generate(15, (index) {
                        return today.subtract(Duration(days: index));
                      });

                      // Group history sessions by date
                      final Map<String, List<WorkoutSession>> sessionsByDate = {};
                      for (var session in history) {
                        sessionsByDate.putIfAbsent(session.date, () => []).add(session);
                      }

                      final datesToShow = _showAllHistoryDates ? past15Days : past15Days.take(5).toList();

                      return Column(
                        children: [
                          ...datesToShow.map((date) {
                            final dateKey = DateFormat('yyyy-MM-dd').format(date);
                            final daySessions = sessionsByDate[dateKey] ?? [];

                            // Format the display date
                            String displayDateStr = '';
                            final diff = today.difference(DateTime(date.year, date.month, date.day)).inDays;
                            if (diff == 0) {
                              displayDateStr = 'Today - ${DateFormat('EEEE, MMM d').format(date)}';
                            } else if (diff == 1) {
                              displayDateStr = 'Yesterday - ${DateFormat('EEEE, MMM d').format(date)}';
                            } else {
                              displayDateStr = DateFormat('EEEE, MMMM d').format(date);
                            }

                            if (daySessions.isEmpty) {
                              // Rest Day
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Opacity(
                                  opacity: 0.65,
                                  child: GlassCard(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.04),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.nights_stay_rounded,
                                              color: AppTheme.textSecondary,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayDateStr,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                'Rest Day • Recovery optimization',
                                                style: TextStyle(
                                                  color: AppTheme.textTertiary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              // Expandable Workout Day
                              final bool isExpanded = _expandedDates.contains(dateKey);
                              final totalCalories = daySessions.fold<int>(0, (sum, s) => sum + (s.durationSeconds ~/ 60) * 6);
                              final totalWorkouts = daySessions.length;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: GlassCard(
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (isExpanded) {
                                              _expandedDates.remove(dateKey);
                                            } else {
                                              _expandedDates.add(dateKey);
                                            }
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.accentCyan.withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.check_circle_rounded,
                                                    color: AppTheme.accentCyan,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      displayDateStr,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '$totalWorkouts Workout${totalWorkouts > 1 ? "s" : ""} logged • $totalCalories kcal',
                                                      style: const TextStyle(
                                                        color: AppTheme.textSecondary,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isExpanded) ...[
                                        const Divider(color: AppTheme.glassBorder, height: 1),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                          child: Column(
                                            children: daySessions.map((session) => _buildHistorySessionCard(session)).toList(),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }
                          }),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showAllHistoryDates = !_showAllHistoryDates;
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              decoration: BoxDecoration(
                                color: AppTheme.accentCyan.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.accentCyan.withOpacity(0.15), width: 1.0),
                              ),
                              child: Center(
                                child: Text(
                                  _showAllHistoryDates ? 'SHOW LESS' : 'SHOW MORE DATES',
                                  style: const TextStyle(
                                    color: AppTheme.accentCyan,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                  )
                ]
              ],
            ),
          )
              : _buildPhysiqueAnalyzerPanel(),
        ),
      ],
    );
  }

  Widget _buildEmptyHistoryCard() {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            color: AppTheme.textSecondary.withOpacity(0.3),
            size: 40,
          ),
          const SizedBox(height: 8),
          const Text(
            'No logged workouts on record.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySessionCard(WorkoutSession session) {
    final parsedDate = DateFormat('yyyy-MM-dd').parse(session.date);
    final dateStr = DateFormat('EEEE, MMMM d').format(parsedDate);
    final durationMin = session.durationSeconds ~/ 60;
    
    // Choose neon accent color based on index to create vibrant diversity
    final int idx = session.date.hashCode;
    final Color accentColor = idx % 3 == 0
        ? AppTheme.accentCyan
        : idx % 3 == 1
            ? AppTheme.accentOrange
            : AppTheme.accentPurple;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accentColor.withOpacity(0.5), width: 2),
              ),
              child: Center(
                child: Icon(
                  Icons.check_circle_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.exercises.isNotEmpty
                        ? '${session.exercises.first.name} Split'
                        : 'Custom split',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dateStr • ${durationMin}m',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (session.exercises.length > 1) ...[
                    const SizedBox(height: 6),
                    Text(
                      session.exercises.skip(1).map((e) => e.name).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    durationMin > 60
                        ? 'HIGH'
                        : durationMin > 35
                            ? 'MEDIUM'
                            : 'RECOVERY',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: '${durationMin * 6} ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: 'kcal'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // VIEW: ACTIVE WORKOUT LOGGER (Gym-Ready)
  // ==========================================
  Widget _buildActiveWorkoutLogger(ActiveWorkout activeWorkout) {
    return Column(
      children: [
        //live live logs toolbar
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showAddExerciseDialog(context),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.accentPurple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.accentPurple.withOpacity(0.3),
                      width: 1.0,
                    ),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          color: AppTheme.accentCyan,
                          size: 18,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Add Exercise',
                          style: TextStyle(
                            color: AppTheme.accentCyan,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => _showFinishWorkoutSheet(context),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Finish Workout',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Expanded(
          child: activeWorkout.exercises.isEmpty
              ? _buildEmptyLiveSessionCard()
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 140),
                  itemCount: activeWorkout.exercises.length,
                  itemBuilder: (context, index) {
                    return _buildLiveExerciseCard(
                      activeWorkout.exercises[index],
                      index,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyLiveSessionCard() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_task_rounded,
            color: AppTheme.textSecondary.withOpacity(0.2),
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Your session exercises array is blank.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap "Add Exercise" to begin logging sets.',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveExerciseCard(ExerciseLog exercise, int exerciseIndex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise header with delete trigger
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      exercise.category.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.accentCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline_rounded,
                    color: AppTheme.accentCoral,
                    size: 20,
                  ),
                  onPressed: () {
                    ref
                        .read(activeWorkoutProvider.notifier)
                        .removeExercise(exerciseIndex);
                  },
                ),
              ],
            ),
            const Divider(color: AppTheme.glassBorder, height: 16),

            // Tabular sets list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exercise.sets.length,
              itemBuilder: (context, setIndex) {
                final set = exercise.sets[setIndex];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      // Set marker index
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: set.isCompleted
                              ? AppTheme.accentEmerald.withOpacity(0.12)
                              : Colors.white.withOpacity(0.04),
                        ),
                        child: Center(
                          child: Text(
                            '${setIndex + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: set.isCompleted
                                  ? AppTheme.accentEmerald
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),                      // Weight adjust parameters (One-hand preset gym buttons + Tap & Type)
                      Expanded(
                        flex: 3,
                        child: WeightAdjuster(
                          weight: set.weight,
                          onDecrement: () {
                            if (set.weight > 0) {
                              ref
                                  .read(activeWorkoutProvider.notifier)
                                  .updateSet(
                                    exerciseIndex,
                                    setIndex,
                                    weight: (set.weight - 2.5)
                                        .clamp(0, 9999)
                                        .toDouble(),
                                  );
                            }
                          },
                          onIncrement: () {
                            ref
                                .read(activeWorkoutProvider.notifier)
                                .updateSet(
                                  exerciseIndex,
                                  setIndex,
                                  weight: set.weight + 2.5,
                                );
                          },
                          onChanged: (val) {
                            ref
                                .read(activeWorkoutProvider.notifier)
                                .updateSet(
                                  exerciseIndex,
                                  setIndex,
                                  weight: val,
                                );
                          },
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Reps adjust parameters (One-hand + Tap & Type)
                      Expanded(
                        flex: 2,
                        child: RepsAdjuster(
                          reps: set.reps,
                          onDecrement: () {
                            if (set.reps > 0) {
                              ref
                                  .read(activeWorkoutProvider.notifier)
                                  .updateSet(
                                    exerciseIndex,
                                    setIndex,
                                    reps: set.reps - 1,
                                  );
                            }
                          },
                          onIncrement: () {
                            ref
                                .read(activeWorkoutProvider.notifier)
                                .updateSet(
                                  exerciseIndex,
                                  setIndex,
                                  reps: set.reps + 1,
                                );
                          },
                          onChanged: (val) {
                            ref
                                .read(activeWorkoutProvider.notifier)
                                .updateSet(
                                  exerciseIndex,
                                  setIndex,
                                  reps: val,
                                );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Completed toggle
                      GestureDetector(
                        onTap: () {
                          ref
                              .read(activeWorkoutProvider.notifier)
                              .updateSet(
                                exerciseIndex,
                                setIndex,
                                isCompleted: !set.isCompleted,
                              );
                          if (!set.isCompleted) {
                            // Start short rest timer popup notification
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Set complete! Rest timer initialized.',
                                ),
                                duration: Duration(seconds: 2),
                                backgroundColor: AppTheme.accentPurple,
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: set.isCompleted
                                ? AppTheme.accentEmerald.withOpacity(0.12)
                                : Colors.transparent,
                            border: Border.all(
                              color: set.isCompleted
                                  ? AppTheme.accentEmerald
                                  : AppTheme.glassBorder,
                              width: 1.5,
                            ),
                          ),
                          child: set.isCompleted
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppTheme.accentEmerald,
                                  size: 16,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Remove set trigger
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppTheme.textTertiary,
                          size: 16,
                        ),
                        onPressed: () {
                          ref
                              .read(activeWorkoutProvider.notifier)
                              .removeSet(exerciseIndex, setIndex);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 10),
            // Add Set button inside exercise card
            GestureDetector(
              onTap: () {
                ref.read(activeWorkoutProvider.notifier).addSet(exerciseIndex);
              },
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.glassBorder, width: 0.8),
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        color: AppTheme.textSecondary,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Add Set',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ==========================================
  // LIVE MODALS & SEARCH DIALOGS
  // ==========================================

  void _showAddExerciseDialog(BuildContext context) {
    _searchController.clear();
    _selectedCategoryFilter = 'All';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setStateDialog) {
            // Apply searches and category filters
            final query = _searchController.text.toLowerCase().trim();
            final filtered = _exerciseLibrary.where((ex) {
              final matchCat =
                  _selectedCategoryFilter == 'All' ||
                  ex['category'] == _selectedCategoryFilter;
              final matchQuery =
                  query.isEmpty || ex['name']!.toLowerCase().contains(query);
              return matchCat && matchQuery;
            }).toList();

            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final dialogBg = isDark ? AppTheme.glassBackground : Colors.white;
            final dialogBorder = isDark ? AppTheme.glassBorder : const Color(0xFFEADBFF);

            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: dialogBorder, width: 1.0),
              ),
              title: const Text(
                'Add Gym Exercise',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.glassBorder,
                          width: 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Search exercise...',
                          border: InputBorder.none,
                          icon: Icon(Icons.search_rounded, size: 18),
                        ),
                        onChanged: (text) {
                          setStateDialog(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Categories Horizontal Filter list
                    SizedBox(
                      height: 28,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children:
                            [
                              'All',
                              'Chest',
                              'Back',
                              'Legs',
                              'Arms',
                              'Shoulders',
                              'Cardio',
                            ].map((cat) {
                              final selected = _selectedCategoryFilter == cat;
                              return GestureDetector(
                                onTap: () {
                                  setStateDialog(() {
                                    _selectedCategoryFilter = cat;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppTheme.accentCyan
                                        : Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      cat,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: selected
                                            ? Colors.white
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Exercise options list
                    Expanded(
                      child: filtered.isEmpty
                          ? _buildCreateCustomExercisePanel(setStateDialog)
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    item['name']!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    item['category']!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: AppTheme.accentCyan,
                                  ),
                                  onTap: () {
                                    ref
                                        .read(activeWorkoutProvider.notifier)
                                        .addExercise(
                                          item['name']!,
                                          item['category']!,
                                        );
                                    Navigator.of(ctx).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCreateCustomExercisePanel(StateSetter setStateDialog) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No exercise found.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customExerciseController,
              decoration: InputDecoration(
                hintText: 'Enter custom name...',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.glassBorder),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Create Custom Exercise',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                final name = _customExerciseController.text.trim();
                if (name.isNotEmpty) {
                  ref
                      .read(activeWorkoutProvider.notifier)
                      .addExercise(name, 'Chest');
                  _customExerciseController.clear();
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFinishWorkoutSheet(BuildContext context) {
    bool saveAsTemplate = false;
    final templateNameController = TextEditingController(text: 'My Workout Preset');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? AppTheme.glassBackground : Colors.white;

        return StatefulBuilder(
          builder: (dialogCtx, setStateSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Finish live Session',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Save sets metrics and gym training duration to local history.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // Notes input field
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            'Add workout notes (e.g. felt strong on Squat)...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.accentCyan),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Save as Preset Checkbox Row
                    Row(
                      children: [
                        Checkbox(
                          value: saveAsTemplate,
                          activeColor: AppTheme.accentCyan,
                          onChanged: (val) {
                            setStateSheet(() {
                              saveAsTemplate = val ?? false;
                            });
                          },
                        ),
                        const Text(
                          'Save as reusable Workout Preset',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (saveAsTemplate) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: templateNameController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Enter template name (e.g. Heavy Legs)...',
                          labelText: 'Preset Template Name',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.glassBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.accentCyan),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Finish Submit Button
                    GestureDetector(
                      onTap: () async {
                        _gymTimer?.stop();
                        final notes = _notesController.text.trim();

                        if (saveAsTemplate &&
                            templateNameController.text.trim().isNotEmpty) {
                          final active = ref.read(activeWorkoutProvider);
                          final exData = active.exercises.map((ex) => {
                            'name': ex.name,
                            'category': ex.category,
                          }).toList();
                          await StorageService.saveWorkoutTemplate({
                            'name': templateNameController.text.trim(),
                            'exercises': exData,
                          });
                        }

                        await ref
                            .read(activeWorkoutProvider.notifier)
                            .finishWorkout(notes);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Workout session saved successfully!'),
                            backgroundColor: AppTheme.accentEmerald,
                          ),
                        );
                        setState(() {});
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'Complete Session',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // PHYSIQUE PHOTO JOURNAL & SIDE-BY-SIDE ANALYSER
  // ==========================================

  void _uploadPhotoForDate(String dateStr) {
    ImagePickerHelper.pickImage((base64, name, filePath) async {
      final metrics = StorageService.getDailyMetrics(dateStr);
      metrics['gym_pic'] = base64;
      
      await ref.read(dailyMetricsProvider(dateStr).notifier).saveMetrics(metrics);
      
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Physique photo uploaded for $dateStr!'),
            backgroundColor: AppTheme.accentPurple,
          ),
        );
      }
    });
  }

  void _deletePhotoForDate(String dateStr) async {
    final metrics = StorageService.getDailyMetrics(dateStr);
    metrics.remove('gym_pic');
    
    await ref.read(dailyMetricsProvider(dateStr).notifier).saveMetrics(metrics);
    
    if (_selectedBeforeDate == dateStr) _selectedBeforeDate = null;
    if (_selectedAfterDate == dateStr) _selectedAfterDate = null;

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Physique photo deleted.'),
          backgroundColor: AppTheme.accentCoral,
        ),
      );
    }
  }

  void _showFullImageDialog(BuildContext context, String dateStr, String base64Pic) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  base64Decode(base64Pic),
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }



  Widget _buildPhotoJournal() {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DAILY PHYSIQUE PHOTO JOURNAL',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppTheme.accentPurple,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 15,
            itemBuilder: (context, index) {
              final date = now.subtract(Duration(days: index));
              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              final label = index == 0
                  ? 'Today'
                  : (index == 1 ? 'Yesterday' : DateFormat('MMM d').format(date));
              
              final metrics = StorageService.getDailyMetrics(dateStr);
              final String? base64Pic = metrics['gym_pic'] as String?;

              return Container(
                width: 90,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (base64Pic != null) {
                            _showFullImageDialog(context, dateStr, base64Pic);
                          } else {
                            _uploadPhotoForDate(dateStr);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: base64Pic != null ? AppTheme.accentPurple : AppTheme.glassBorder,
                              width: base64Pic != null ? 1.5 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: base64Pic != null
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(
                                        base64Decode(base64Pic),
                                        fit: BoxFit.cover,
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => _deletePhotoForDate(dateStr),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.delete_rounded,
                                              color: AppTheme.accentCoral,
                                              size: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.add_a_photo_rounded,
                                      color: AppTheme.textSecondary,
                                      size: 20,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showFullscreenCompareDialog(BuildContext context, String beforeBase64, String afterBase64) {
    showDialog(
      context: context,
      builder: (context) {
        double localSplit = 0.5;
        BoxFit localFit = BoxFit.contain; // Start with contain so they see the full image without cropping!
        
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Dialog(
              backgroundColor: isDark ? const Color(0xEC090E18) : Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? AppTheme.glassBorder : const Color(0xFFEADBFF),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Physique Comparison',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Slide to compare before & after (entire image visible)',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                // Toggle fit button
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      localFit = localFit == BoxFit.cover ? BoxFit.contain : BoxFit.cover;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentPurple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.accentPurple.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          localFit == BoxFit.cover ? Icons.aspect_ratio_rounded : Icons.crop_free_rounded,
                                          color: AppTheme.accentPurple,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          localFit == BoxFit.cover ? 'Fit Screen' : 'Fill Screen',
                                          style: const TextStyle(
                                            color: AppTheme.accentPurple,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.04),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: AppTheme.textSecondary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // The Slider container taking up the rest of the space
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final height = constraints.maxHeight;
                              return GestureDetector(
                                onHorizontalDragUpdate: (details) {
                                  final RenderBox renderBox = context.findRenderObject() as RenderBox;
                                  final localPos = renderBox.globalToLocal(details.globalPosition);
                                  setState(() {
                                    localSplit = (localPos.dx / width).clamp(0.0, 1.0);
                                  });
                                },
                                child: Container(
                                  width: width,
                                  height: height,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.glassBorder, width: 1),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Image.memory(
                                            base64Decode(beforeBase64),
                                            fit: localFit,
                                          ),
                                        ),
                                        Positioned(
                                          left: 0,
                                          top: 0,
                                          bottom: 0,
                                          width: width * localSplit,
                                          child: ClipRect(
                                            child: SizedBox(
                                              width: width,
                                              height: height,
                                              child: Image.memory(
                                                base64Decode(afterBase64),
                                                fit: localFit,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 12,
                                          top: 12,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.6),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'AFTER',
                                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 12,
                                          top: 12,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.6),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'BEFORE',
                                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: (width * localSplit) - 1.5,
                                          top: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 3,
                                            color: AppTheme.accentPurple,
                                          ),
                                        ),
                                        Positioned(
                                          left: (width * localSplit) - 14,
                                          top: (height / 2) - 14,
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: const BoxDecoration(
                                              color: AppTheme.accentPurple,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.unfold_more_rounded,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSplitSlider(String beforeBase64, String afterBase64) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = 280.0;
        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            final RenderBox renderBox = context.findRenderObject() as RenderBox;
            final localPos = renderBox.globalToLocal(details.globalPosition);
            setState(() {
              _splitPercentage = (localPos.dx / width).clamp(0.0, 1.0);
            });
          },
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.glassBorder, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.memory(
                      base64Decode(beforeBase64),
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: width * _splitPercentage,
                    child: ClipRect(
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: Image.memory(
                          base64Decode(afterBase64),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AFTER',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'BEFORE',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (width * _splitPercentage) - 1.5,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 3,
                      color: AppTheme.accentPurple,
                    ),
                  ),
                  Positioned(
                    left: (width * _splitPercentage) - 14,
                    top: (height / 2) - 14,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentPurple,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.unfold_more_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: GestureDetector(
                      onTap: () => _showFullscreenCompareDialog(context, beforeBase64, afterBase64),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhysiqueAnalyzerPanel() {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.white.withOpacity(0.015) : Colors.black.withOpacity(0.01);

    final List<String> datesWithPhotos = [];
    final List<String> dropdownLabels = [];
    for (int i = 0; i < 30; i++) {
      final day = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(day);
      final metrics = StorageService.getDailyMetrics(dateStr);
      if (metrics['gym_pic'] != null) {
        datesWithPhotos.add(dateStr);
        dropdownLabels.add(DateFormat('MMMM d, yyyy').format(day));
      }
    }

    if (datesWithPhotos.isNotEmpty) {
      if (_selectedBeforeDate == null || !datesWithPhotos.contains(_selectedBeforeDate)) {
        _selectedBeforeDate = datesWithPhotos.last;
      }
      if (_selectedAfterDate == null || !datesWithPhotos.contains(_selectedAfterDate)) {
        _selectedAfterDate = datesWithPhotos.first;
      }
      if (datesWithPhotos.length >= 2 && _selectedBeforeDate == _selectedAfterDate) {
        _selectedBeforeDate = datesWithPhotos.last;
        _selectedAfterDate = datesWithPhotos.first;
      }
    } else {
      _selectedBeforeDate = null;
      _selectedAfterDate = null;
    }

    String? beforePic;
    String? afterPic;
    if (_selectedBeforeDate != null) {
      beforePic = StorageService.getDailyMetrics(_selectedBeforeDate!)['gym_pic'] as String?;
    }
    if (_selectedAfterDate != null) {
      afterPic = StorageService.getDailyMetrics(_selectedAfterDate!)['gym_pic'] as String?;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPhotoJournal(),
          const SizedBox(height: 28),

          Text(
            'PHYSIQUE SCAN & COMPARISON',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textPrimary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          if (datesWithPhotos.length < 2) ...[
            GlassCard(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppTheme.accentPurple, size: 36),
                  const SizedBox(height: 12),
                  const Text(
                    'Upload More Photos to Compare',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You need at least 2 photos logged on different days to unlock the side-by-side comparisons and AI scanner analyzer. Tap "+" on the days above to upload.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Before Photo', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.glassBorder, width: 0.8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedBeforeDate,
                            isExpanded: true,
                            dropdownColor: AppTheme.obsidianBackground,
                            style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                            items: List.generate(datesWithPhotos.length, (idx) {
                              return DropdownMenuItem(
                                value: datesWithPhotos[idx],
                                child: Text(dropdownLabels[idx]),
                              );
                            }),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedBeforeDate = val;
                                  if (_selectedBeforeDate == _selectedAfterDate && datesWithPhotos.length >= 2) {
                                    _selectedAfterDate = datesWithPhotos.firstWhere((d) => d != val);
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('After Photo', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.glassBorder, width: 0.8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedAfterDate,
                            isExpanded: true,
                            dropdownColor: AppTheme.obsidianBackground,
                            style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                            items: List.generate(datesWithPhotos.length, (idx) {
                              return DropdownMenuItem(
                                value: datesWithPhotos[idx],
                                child: Text(dropdownLabels[idx]),
                              );
                            }),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedAfterDate = val;
                                  if (_selectedBeforeDate == _selectedAfterDate && datesWithPhotos.length >= 2) {
                                    _selectedBeforeDate = datesWithPhotos.lastWhere((d) => d != val);
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (beforePic != null && afterPic != null) ...[
              _buildSplitSlider(beforePic, afterPic),
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: Text('Selected photos not found.', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ==========================================
// STATEFUL ADJUSTERS (SUPPORTING TAP & TYPE)
// ==========================================

class WeightAdjuster extends StatefulWidget {
  final double weight;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final ValueChanged<double> onChanged;

  const WeightAdjuster({
    super.key,
    required this.weight,
    required this.onDecrement,
    required this.onIncrement,
    required this.onChanged,
  });

  @override
  State<WeightAdjuster> createState() => _WeightAdjusterState();
}

class _WeightAdjusterState extends State<WeightAdjuster> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.weight));
  }

  @override
  void didUpdateWidget(covariant WeightAdjuster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.weight != oldWidget.weight) {
      final newText = _format(widget.weight);
      if (_controller.text != newText) {
        _controller.text = newText;
      }
    }
  }

  String _format(double val) {
    if (val == 0.0) return '0';
    return val.toString().replaceAll(RegExp(r'\.0$'), '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.glassBorder, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: widget.onDecrement,
            child: Container(
              width: 24,
              height: double.infinity,
              color: Colors.transparent,
              child: const Icon(
                Icons.remove_rounded,
                color: AppTheme.textSecondary,
                size: 14,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (text) {
                      final val = double.tryParse(text);
                      if (val != null) {
                        widget.onChanged(val);
                      }
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 6.0),
                  child: Text(
                    'kg',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onIncrement,
            child: Container(
              width: 24,
              height: double.infinity,
              color: Colors.transparent,
              child: const Icon(
                Icons.add_rounded,
                color: AppTheme.textSecondary,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RepsAdjuster extends StatefulWidget {
  final int reps;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final ValueChanged<int> onChanged;

  const RepsAdjuster({
    super.key,
    required this.reps,
    required this.onDecrement,
    required this.onIncrement,
    required this.onChanged,
  });

  @override
  State<RepsAdjuster> createState() => _RepsAdjusterState();
}

class _RepsAdjusterState extends State<RepsAdjuster> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.reps.toString());
  }

  @override
  void didUpdateWidget(covariant RepsAdjuster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reps != oldWidget.reps) {
      if (_controller.text != widget.reps.toString()) {
        _controller.text = widget.reps.toString();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.glassBorder, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: widget.onDecrement,
            child: Container(
              width: 22,
              height: double.infinity,
              color: Colors.transparent,
              child: const Icon(
                Icons.remove_rounded,
                color: AppTheme.textSecondary,
                size: 14,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (text) {
                      final val = int.tryParse(text);
                      if (val != null) {
                        widget.onChanged(val);
                      }
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 4.0),
                  child: Text(
                    'reps',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onIncrement,
            child: Container(
              width: 22,
              height: double.infinity,
              color: Colors.transparent,
              child: const Icon(
                Icons.add_rounded,
                color: AppTheme.textSecondary,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
