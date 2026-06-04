import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
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
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
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
                color: const Color(0xFF00F2FE).withValues(alpha: 0.1),
              ),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 28.0, vertical: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // App Icon/Brand Header
                      Center(
                        child: Hero(
                          tag: 'app_logo',
                          child: Container(
                            height: 80,
                            width: 80,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13141F),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF1F2030),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6)
                                      .withValues(alpha: 0.2),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/icons/Connect Icon2.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Text Headers
                      const Text(
                        "Connect",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (!_isOtpMode)
                        Text(
                          _isSignIn
                              ? "Your close circle, not your contacts list."
                              : "Create an account to build your cards & sync contacts",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF8B8C9E),
                            fontSize: 14,
                          ),
                        ),
                      const SizedBox(height: 40),

                      if (_isOtpMode) ...[
                        const Text(
                          "Verify Your Email",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "We've sent a 6-digit confirmation code to\n${_emailController.text.trim()}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF8B8C9E),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildInputField(
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
                        const SizedBox(height: 32),
                        _buildOtpSubmitButton(),
                        const SizedBox(height: 18),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isOtpMode = false;
                              _otpController.clear();
                            });
                          },
                          child: const Text(
                            "Back to Sign Up",
                            style: TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ] else ...[
                        // Sliding Tab Switcher
                        _buildAuthToggle(),
                        const SizedBox(height: 28),

                        // Email Field
                        _buildInputField(
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
                        const SizedBox(height: 18),

                        // Password Field
                        _buildInputField(
                          controller: _passwordController,
                          hint: "Password",
                          icon: Icons.lock_rounded,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: const Color(0xFF5C5E78),
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

                        if (!_isSignIn) ...[
                          const SizedBox(height: 18),
                          // Confirm Password Field
                          _buildInputField(
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
                        ],

                        const SizedBox(height: 32),

                        // Submit Button
                        _buildSubmitButton(),
                        const SizedBox(height: 24),

                        // Divider "OR"
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(
                                color: Color(0xFF1F2030),
                                thickness: 1.5,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                "OR CONTINUE WITH",
                                style: TextStyle(
                                  color: const Color(0xFF5C5E78),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(
                                color: Color(0xFF1F2030),
                                thickness: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Google Sign In Button
                        _buildGoogleButton(),
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
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAuthToggle() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF1F2030),
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
                  borderRadius: BorderRadius.circular(20),
                  color:
                      _isSignIn ? const Color(0xFF1C1D2A) : Colors.transparent,
                ),
                child: Text(
                  "Sign In",
                  style: TextStyle(
                    color: _isSignIn ? Colors.white : const Color(0xFF8B8C9E),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
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
                  borderRadius: BorderRadius.circular(20),
                  color:
                      !_isSignIn ? const Color(0xFF1C1D2A) : Colors.transparent,
                ),
                child: Text(
                  "Sign Up",
                  style: TextStyle(
                    color: !_isSignIn ? Colors.white : const Color(0xFF8B8C9E),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
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
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: const Color(0xFF8B5CF6),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF5C5E78), size: 22),
        suffixIcon: suffixIcon,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF5C5E78), fontSize: 14),
        filled: true,
        fillColor: const Color(0xFF13141F),
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1F2030), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF00F2FE),
            Color(0xFF8B5CF6),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _submit,
        child: Text(
          _isSignIn ? "Sign In" : "Sign Up",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1F2030),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _signInWithGoogle,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Styled Custom Google Icon representation
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.g_mobiledata_rounded,
                color: Colors.black,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Continue with Google",
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpSubmitButton() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF00F2FE),
            Color(0xFF8B5CF6),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            _verifyOtp();
          }
        },
        child: const Text(
          "Verify Code",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
