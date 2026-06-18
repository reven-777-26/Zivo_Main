import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../services/premium_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadOfferings();
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

  Future<void> _handlePurchase() async {
    if (_selectedPackage == null) return;
    setState(() => _isPurchasing = true);

    final success = await PremiumService.purchasePackage(_selectedPackage!);
    setState(() => _isPurchasing = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Welcome to Zivofit Premium! 🎉"),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(); // Go back
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Purchase could not be completed. Please try again."),
            backgroundColor: Colors.redAccent,
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Purchases successfully restored! 🎉"),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No active subscriptions found to restore."),
            backgroundColor: Colors.orangeAccent,
          ),
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
                                title: "Unlimited AI Food & Barcode Scans",
                                subtitle: "No daily restrictions on AI image or barcode parsing.",
                              ),
                              Divider(height: 24, color: Colors.white12),
                              _BenefitRow(
                                title: "Personalized Physique Analysis",
                                subtitle: "Track progress with AI-powered skin and pose assessments.",
                              ),
                              Divider(height: 24, color: Colors.white12),
                              _BenefitRow(
                                title: "Advanced PDF Reports",
                                subtitle: "Export professional logs and summaries for your coach.",
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
                      style: const TextStyle(color: Colors.white54, fontSize: 12.0),
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
      {"id": "monthly", "title": "Monthly Premium", "price": "\$4.99 / mo", "desc": "Billed monthly, cancel anytime"},
      {"id": "yearly", "title": "Yearly Premium (Save 40%)", "price": "\$34.99 / yr", "desc": "Billed annually, 7-day free trial"},
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
            final isSelected = _selectedPackage == null && index == 0; // Default selection mock
            
            return Container(
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
                        style: const TextStyle(color: Colors.white54, fontSize: 12.0),
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
                  color: Colors.white54,
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
