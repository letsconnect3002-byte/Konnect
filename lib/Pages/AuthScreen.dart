import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:connect/Config/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isSignIn = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isOtpMode = false;
  String? _selectedGender;
  bool _isRecoveryMode = false;
  bool _isRecoveryOtpMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      if (_isSignIn) {
        // Sign In
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        // Sign Up
        final confirmPassword = _confirmPasswordController.text.trim();
        if (password != confirmPassword) {
          throw Exception("Passwords do not match");
        }

        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {
            'gender': _selectedGender,
          },
        );

        if (mounted) {
          setState(() {
            _isOtpMode = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Account created! Please check your email for the 6-digit verification code."),
              backgroundColor: Color(0xFF8B5CF6),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final token = _otpController.text.trim();

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter the verification code"),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.signup,
        token: token,
        email: email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Verification successful! Logging you in..."),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    try {
      // Initialize GoogleSignIn (singleton)
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '150827597127-gnh9lamc1ed61u9hcd31f0e8ilri4g5n.apps.googleusercontent.com',
      );

      // Await the native authenticate() method to retrieve the user's GoogleSignInAccount
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      // Retrieve the corresponding GoogleSignInAuthentication object
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Google Sign-In failed: No ID Token found.');
      }

      // Pass these tokens to Supabase using signInWithIdToken
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Sign-In was cancelled'),
              backgroundColor: Colors.orangeAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: ${e.description}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete Google Sign In: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _forgotPassword() {
    setState(() {
      _isSignIn = false;
      _isRecoveryMode = true;
    });
  }

  Future<void> _sendRecoveryCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter your email address"),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
      );
      if (mounted) {
        setState(() {
          _isRecoveryMode = false;
          _isRecoveryOtpMode = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Recovery code sent! Please check your email."),
            backgroundColor: Color(0xFF8B5CF6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyRecoveryOtp() async {
    final email = _emailController.text.trim();
    final token = _otpController.text.trim();

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter the recovery code"),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.recovery,
        token: token,
        email: email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Code verified! Redirecting to reset password..."),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background decorative gradient circles
          Positioned(
            top: -size.height * 0.15,
            right: -size.width * 0.15,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.accentPrimary.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.2,
            left: -size.width * 0.2,
            child: Container(
              width: size.width * 0.9,
              height: size.width * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.accentSecondary.withValues(alpha: 0.04),
              ),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // App Icon/Brand Header (Left-aligned)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Hero(
                          tag: 'app_logo',
                          child: Container(
                            height: 64,
                            width: 64,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: context.surfacePrimary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.04),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.accentPrimary
                                      .withValues(alpha: 0.1),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/icons/Mandala Icon 1.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_isOtpMode) ...[
                        Text(
                          "Verify Your Email",
                          textAlign: TextAlign.left,
                          style: context.displayHeader,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "We've sent a 6-digit confirmation code to ${_emailController.text.trim()}",
                          textAlign: TextAlign.left,
                          style: context.bodyText
                              .copyWith(color: context.textSecondary),
                        ),
                        const SizedBox(
                            height:
                                24), // Vertical spacer of 24 between subtitle and input form
                        _buildInputField(
                          context,
                          controller: _otpController,
                          hint: "6-Digit Verification Code",
                          icon: Icons.pin_rounded,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Verification code is required";
                            }
                            if (value.trim().length != 6) {
                              return "Code must be 6 digits";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildOtpSubmitButton(context),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isOtpMode = false;
                              _otpController.clear();
                            });
                          },
                          child: Text(
                            "Back to Sign Up",
                            style: TextStyle(
                              color: context.accentPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ] else if (_isRecoveryOtpMode) ...[
                        Text(
                          "Verify Recovery Code",
                          textAlign: TextAlign.left,
                          style: context.displayHeader,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "We've sent a 6-digit recovery code to ${_emailController.text.trim()}",
                          textAlign: TextAlign.left,
                          style: context.bodyText
                              .copyWith(color: context.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        _buildInputField(
                          context,
                          controller: _otpController,
                          hint: "6-Digit Recovery Code",
                          icon: Icons.pin_rounded,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Recovery code is required";
                            }
                            if (value.trim().length != 6) {
                              return "Code must be 6 digits";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildRecoveryOtpSubmitButton(context),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isRecoveryOtpMode = false;
                              _isSignIn = true;
                              _otpController.clear();
                            });
                          },
                          child: Text(
                            "Back to Sign In",
                            style: TextStyle(
                              color: context.accentPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ] else if (_isRecoveryMode) ...[
                        Text(
                          "Reset Password",
                          textAlign: TextAlign.left,
                          style: context.displayHeader,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Enter your email address to receive a 6-digit recovery code.",
                          textAlign: TextAlign.left,
                          style: context.bodyText
                              .copyWith(color: context.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        _buildInputField(
                          context,
                          controller: _emailController,
                          hint: "Email Address",
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Email is required";
                            }
                            final emailRegExp = RegExp(
                              r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
                            );
                            if (!emailRegExp.hasMatch(value.trim())) {
                              return "Please enter a valid email address";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildSendRecoveryCodeButton(context),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isRecoveryMode = false;
                              _isSignIn = true;
                            });
                          },
                          child: Text(
                            "Back to Sign In",
                            style: TextStyle(
                              color: context.accentPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ] else ...[
                        // Main Welcome Headers (Left-aligned)
                        Text(
                          _isSignIn ? "Hey, pull up." : "We're letting you in.",
                          textAlign: TextAlign.left,
                          style: context.displayHeader,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isSignIn
                              ? "back with the real ones."
                              : "no randoms, no noise. just the people you actually see IRL.",
                          textAlign: TextAlign.left,
                          style: context.bodyText
                              .copyWith(color: context.textSecondary),
                        ),
                        const SizedBox(
                            height:
                                24), // Vertical spacer of 24 between subtitle and inputs

                        // Sliding Tab Switcher
                        _buildAuthToggle(context),
                        const SizedBox(height: 24),

                        // Email Field
                        _buildInputField(
                          context,
                          controller: _emailController,
                          hint: "Email Address",
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Email is required";
                            }
                            final emailRegExp = RegExp(
                              r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
                            );
                            if (!emailRegExp.hasMatch(value.trim())) {
                              return "Please enter a valid email address";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        _buildInputField(
                          context,
                          controller: _passwordController,
                          hint: "Password",
                          icon: Icons.lock_rounded,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: context.textMuted,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(
                                  () => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Password is required";
                            }
                            if (value.trim().length < 6) {
                              return "Password must be at least 6 characters";
                            }
                            return null;
                          },
                        ),

                        if (_isSignIn) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _forgotPassword,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                "Forgot Password?",
                                style: TextStyle(
                                  color: context.accentPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ),
                        ],

                        if (!_isSignIn) ...[
                          const SizedBox(height: 16),
                          // Confirm Password Field
                          _buildInputField(
                            context,
                            controller: _confirmPasswordController,
                            hint: "Confirm Password",
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Please confirm your password";
                              }
                              if (value.trim() !=
                                  _passwordController.text.trim()) {
                                return "Passwords do not match";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Gender Selection Field
                          _buildGenderDropdown(context),
                        ],

                        const SizedBox(height: 32),

                        // Submit Button
                        _buildSubmitButton(context),
                        const SizedBox(height: 24),

                        // Divider "OR"
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.06),
                                thickness: 1.0,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                "OR CONTINUE WITH",
                                style: context.captionText.copyWith(
                                  color: context.textMuted,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.06),
                                thickness: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Google Sign In Button
                        _buildGoogleButton(context),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Loading Overlay Indicator
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(context.accentPrimary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAuthToggle(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isSignIn) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isSignIn = true;
                    _formKey.currentState?.reset();
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusComponent - 4),
                  color:
                      _isSignIn ? context.surfaceSecondary : Colors.transparent,
                ),
                child: Text(
                  "I'm in",
                  style: TextStyle(
                    color:
                        _isSignIn ? context.textPrimary : context.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isSignIn) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isSignIn = false;
                    _formKey.currentState?.reset();
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusComponent - 4),
                  color: !_isSignIn
                      ? context.surfaceSecondary
                      : Colors.transparent,
                ),
                child: Text(
                  "Sign Up",
                  style: TextStyle(
                    color: !_isSignIn
                        ? context.textPrimary
                        : context.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: context.bodyText,
      cursorColor: context.accentPrimary,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: context.textMuted, size: 20),
        suffixIcon: suffixIcon,
        hintText: hint,
        hintStyle: context.bodyText.copyWith(color: context.textMuted),
        filled: true,
        fillColor: context.surfaceSecondary,
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
          borderSide: BorderSide(color: context.accentPrimary, width: 1.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildGenderDropdown(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedGender,
      dropdownColor: context.surfaceSecondary,
      style: context.bodyText,
      icon: Icon(Icons.arrow_drop_down_rounded,
          color: context.textMuted, size: 28),
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.wc_rounded, color: context.textMuted, size: 20),
        hintText: "Select Gender",
        hintStyle: context.bodyText.copyWith(color: context.textMuted),
        filled: true,
        fillColor: context.surfaceSecondary,
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
          borderSide: BorderSide(color: context.accentPrimary, width: 1.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusComponent),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
      ),
      items: const [
        DropdownMenuItem(value: "Male", child: Text("Male")),
        DropdownMenuItem(value: "Female", child: Text("Female")),
        DropdownMenuItem(value: "Others", child: Text("Others")),
      ],
      onChanged: (value) {
        setState(() {
          _selectedGender = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Please select your gender";
        }
        return null;
      },
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        boxShadow: [
          BoxShadow(
            color: context.accentPrimary.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: context.accentPrimary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          ),
        ),
        onPressed: _submit,
        child: Text(
          _isSignIn ? "I'm in" : "I'm in",
          style: context.cardTitle.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: context.surfacePrimary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        onTap: _signInWithGoogle,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/Google-Sign-in.png',
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Text(
              "Continue with Google",
              style: context.cardTitle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpSubmitButton(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        boxShadow: [
          BoxShadow(
            color: context.accentPrimary.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: context.accentPrimary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          ),
        ),
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            _verifyOtp();
          }
        },
        child: Text(
          "Verify Code",
          style: context.cardTitle.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRecoveryOtpSubmitButton(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        boxShadow: [
          BoxShadow(
            color: context.accentPrimary.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: context.accentPrimary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          ),
        ),
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            _verifyRecoveryOtp();
          }
        },
        child: Text(
          "Verify Code",
          style: context.cardTitle.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSendRecoveryCodeButton(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        boxShadow: [
          BoxShadow(
            color: context.accentPrimary.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: context.accentPrimary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          ),
        ),
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            _sendRecoveryCode();
          }
        },
        child: Text(
          "Send Recovery Code",
          style: context.cardTitle.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
