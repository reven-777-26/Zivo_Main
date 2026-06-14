import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/logo_widget.dart';
import '../../services/firebase_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUp) {
        await FirebaseService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cred = await FirebaseService.signInWithGoogle();
      if (cred != null && mounted) {
        context.go('/home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseService.signInAnonymously();
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFE8EBE6) : AppTheme.textPrimary;
    final bgColor = isDark ? const Color(0xFF0E0F0C) : AppTheme.obsidianBackground;

    return Scaffold(
      backgroundColor: bgColor,
      body: Container(
        color: bgColor,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Branding
                  const ZivoLogoWidget(size: 80)
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 16),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Outfit',
                        letterSpacing: -0.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'Zivo',
                          style: TextStyle(color: textColor),
                        ),
                        TextSpan(
                          text: 'Fit',
                          style: const TextStyle(color: Color(0xFFB2D300)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp ? 'Create your profile to start syncing' : 'Welcome back! Sign in to sync data',
                    style: TextStyle(color: isDark ? const Color(0xFFCCCCCC) : AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Auth Card
                  GlassCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.accentCoral.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.accentCoral, width: 0.5),
                              ),
                              child: Text(
                                _errorMessage!,
                            style: TextStyle(color: isDark ? AppTheme.accentCoral : const Color(0xFFD03238), fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Email Address',
                              hintStyle: TextStyle(color: isDark ? AppTheme.textSecondary : AppTheme.textTertiary),
                              prefixIcon: Icon(Icons.email_outlined, color: isDark ? AppTheme.textSecondary : AppTheme.textTertiary),
                              filled: true,
                              fillColor: isDark ? Colors.black.withOpacity(0.4) : const Color(0xFFF0F2EE),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder, width: 1.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder, width: 1.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty || !val.contains('@')) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Password',
                              hintStyle: TextStyle(color: isDark ? AppTheme.textSecondary : AppTheme.textTertiary),
                              prefixIcon: Icon(Icons.lock_outline, color: isDark ? AppTheme.textSecondary : AppTheme.textTertiary),
                              filled: true,
                              fillColor: isDark ? Colors.black.withOpacity(0.4) : const Color(0xFFF0F2EE),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder, width: 1.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder, width: 1.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty || val.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentCyan,
                              foregroundColor: const Color(0xFF0E0F0C), // Ink Black text
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24), // rounded.xl (24px)
                              ),
                            ),
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0E0F0C)),
                                    ),
                                  )
                                : Text(
                                    _isSignUp ? 'Create Account' : 'Sign In',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppTheme.glassBorder)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'OR CONTINUE WITH',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFFCCCCCC).withOpacity(0.6) : AppTheme.textSecondary.withOpacity(0.6),
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                        ),
                      ),
                      const Expanded(child: Divider(color: AppTheme.glassBorder)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Social Logins
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Google Login Button
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder, width: 1.0),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24), // rounded.xl (24px)
                            ),
                          ),
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          icon: Icon(Icons.g_mobiledata, size: 28, color: isDark ? AppTheme.accentCyan : const Color(0xFF163300)),
                          label: Text(
                            'Google',
                            style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Guest Mode Button
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder, width: 1.0),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24), // rounded.xl (24px)
                            ),
                          ),
                          onPressed: _isLoading ? null : _signInAnonymously,
                          icon: Icon(Icons.person_outline, color: isDark ? AppTheme.textSecondary : const Color(0xFF454745)),
                          label: Text(
                            'Guest Mode',
                            style: TextStyle(color: isDark ? AppTheme.textSecondary : const Color(0xFF454745), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Toggle Sign Up / Sign In
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _errorMessage = null;
                      });
                    },
                    child: Text(
                      _isSignUp ? 'Already have an account? Sign In' : "Don't have an account? Sign Up",
                      style: TextStyle(color: isDark ? AppTheme.accentCyan : const Color(0xFF163300), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
