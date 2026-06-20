import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:confetti/confetti.dart';
import '../../services/premium_service.dart';
import '../../services/state_providers.dart';
import '../../services/storage_service.dart';

class PremiumPaywallScreen extends StatefulWidget {
  const PremiumPaywallScreen({super.key});

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen> {
  Offerings? _offerings;
  Package? _selectedPackage;
  bool _isLoading = true;
  bool _isPurchasing = false;
  String _selectedMockPlanId = 'monthly';
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _loadOfferings();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadOfferings() async {
    setState(() => _isLoading = true);
    // Initialize if not already initialized
    if (!PremiumService.isInitialized) {
      await PremiumService.initialize();
    }
    final offerings = await PremiumService.getOfferings();
    setState(() {
      _offerings = offerings;
      _isLoading = false;
      // Default select the first package available
      if (offerings?.current != null && offerings!.current!.availablePackages.isNotEmpty) {
        _selectedPackage = offerings.current!.availablePackages.first;
      }
    });
  }

  void _showPremiumWelcomeDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161814),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFD9FF00).withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD9FF00).withOpacity(0.08),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9FF00).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '👑',
                    style: TextStyle(fontSize: 48),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'WELCOME TO PREMIUM',
                  style: TextStyle(
                    color: Color(0xFFD9FF00),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Zivofit Premium Active',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Thank you for joining Zivofit Premium! You now have unlimited access to all advanced tools, AI-powered insights, custom meal plans, and real-time logs syncing to your profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF868685),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx); // Close dialog
                    context.pop(); // Pop paywall screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD9FF00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text(
                    'START EXPLORING',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handlePurchase() async {
    setState(() => _isPurchasing = true);
    bool success = false;
    if (_selectedPackage != null) {
      success = await PremiumService.purchasePackage(_selectedPackage!);
    } else {
      // Mock purchase in sandbox/test mode
      await Future.delayed(const Duration(seconds: 1));
      await StorageService.savePremiumPlanType(_selectedMockPlanId == 'monthly' ? 'Monthly Plan' : 'Yearly Plan');
      PremiumService.isPremiumNotifier.value = true;
      success = true;
    }
    setState(() => _isPurchasing = false);

    if (mounted) {
      if (success) {
        _confettiController.play();
        _showPremiumWelcomeDialog(context);
      } else {
        showWebNotification(
          "⚠️ Purchase Failed",
          "Purchase could not be completed. Please try again.",
        );
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    final success = await PremiumService.restorePurchases();
    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        _confettiController.play();
        _showPremiumWelcomeDialog(context);
      } else {
        showWebNotification(
          "⚠️ Restore Failed",
          "No active subscriptions found to restore.",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E12), // Sleek Premium Dark Mode
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Color(0xFFD9FF00),
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                ],
              ),
            ),
            // Background ambient glow
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withOpacity(0.08),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.08),
                      blurRadius: 100,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withOpacity(0.05),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.05),
                      blurRadius: 120,
                    ),
                  ],
                ),
              ),
            ),
            
            // Main content
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top close button
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => context.pop(),
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12.0),
                        // Crown Logo
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1.5),
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            size: 40,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        
                        // Header
                        Text(
                          "ZIVOFIT PREMIUM",
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.5,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          "Unlock full potential & track with ease",
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 32.0),
                        
                        // Premium benefits card
                        Container(
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16171E),
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Column(
                            children: const [
                              _BenefitRow(
                                title: "Unlimited AI Scans",
                                subtitle: "Analyze meals, food, supplements & skincare products with no limits.",
                              ),
                              Divider(height: 18, color: Colors.white12),
                              _BenefitRow(
                                title: "Full Food Log System",
                                subtitle: "Log meals using Photo, Barcode, Voice, Describe, and Presets.",
                              ),
                              Divider(height: 18, color: Colors.white12),
                              _BenefitRow(
                                title: "Zivo Analyser",
                                subtitle: "Upload meals, food, supplements, drinks, or skincare products to uncover ingredient risks, nutrition quality, and healthier alternatives.",
                              ),
                              Divider(height: 18, color: Colors.white12),
                              _BenefitRow(
                                title: "Workout Physique & Analytics",
                                subtitle: "Track body progress check-ins and exercise analytics.",
                              ),
                              Divider(height: 18, color: Colors.white12),
                              _BenefitRow(
                                title: "Stats & AI Insights",
                                subtitle: "Access long-term charts and customized coaching warnings.",
                              ),
                              Divider(height: 18, color: Colors.white12),
                              _BenefitRow(
                                title: "Daily Consistency Streaks",
                                subtitle: "Unlock daily consistency calendar grid and streak bottom sheets.",
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32.0),
                        
                        // Offerings / Packages Selector
                        if (_isLoading)
                          const Center(
                            child: CircularProgressIndicator(color: Colors.amber),
                          )
                        else if (_offerings == null || _offerings!.current == null || _offerings!.current!.availablePackages.isEmpty)
                          // Mock products fallback (useful for sandbox/offline)
                          _buildMockPackages()
                        else
                          _buildPackagesList(),
                          
                        const SizedBox(height: 24.0),
                      ],
                    ),
                  ),
                ),
                
                // Bottom Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: (_isPurchasing || _isLoading) ? null : _handlePurchase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          elevation: 3,
                          shadowColor: Colors.amber.withOpacity(0.4),
                        ),
                        child: _isPurchasing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                              )
                            : const Text(
                                "UPGRADE NOW",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _handleRestore,
                            child: const Text(
                              "Restore Purchase",
                              style: TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ),
                          const Text(
                            "Terms & Privacy",
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
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

  Widget _buildPackagesList() {
    final packages = _offerings!.current!.availablePackages;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: packages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12.0),
      itemBuilder: (context, index) {
        final package = packages[index];
        final isSelected = _selectedPackage == package;
        
        return GestureDetector(
          onTap: () => setState(() => _selectedPackage = package),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isSelected ? Colors.amber.withOpacity(0.05) : const Color(0xFF16171E),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: isSelected ? Colors.amber : Colors.white.withOpacity(0.05),
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.storeProduct.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      package.storeProduct.description,
                      style: const TextStyle(color: Colors.white, fontSize: 12.0),
                    ),
                  ],
                ),
                Text(
                  package.storeProduct.priceString,
                  style: TextStyle(
                    color: isSelected ? Colors.amber : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMockPackages() {
    // Return custom mockup package options when sandbox is offline / not configured
    final mockPlans = [
      {"id": "monthly", "title": "Monthly Premium", "price": "₹169 / mo", "desc": "Billed monthly, cancel anytime"},
      {"id": "yearly", "title": "Yearly Premium (Save 55%)", "price": "₹899 / yr", "desc": "Billed annually, 7-day free trial"},
    ];
    
    return Column(
      children: [
        const Text(
          "Sandbox Mock Plans (Play Console Offline)",
          style: TextStyle(color: Colors.white30, fontSize: 12.0, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 8.0),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: mockPlans.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12.0),
          itemBuilder: (context, index) {
            final plan = mockPlans[index];
            final isSelected = _selectedMockPlanId == plan["id"];
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMockPlanId = plan["id"]!;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.amber.withOpacity(0.05) : const Color(0xFF16171E),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: isSelected ? Colors.amber : Colors.white.withOpacity(0.05),
                    width: isSelected ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan["title"]!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          plan["desc"]!,
                          style: const TextStyle(color: Colors.white, fontSize: 12.0),
                        ),
                      ],
                    ),
                    Text(
                      plan["price"]!,
                      style: TextStyle(
                        color: isSelected ? Colors.amber : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18.0,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String title;
  final String subtitle;

  const _BenefitRow({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2.0),
          child: Icon(Icons.check_circle_outline_rounded, color: Colors.amber, size: 20),
        ),
        const SizedBox(width: 14.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15.0,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
