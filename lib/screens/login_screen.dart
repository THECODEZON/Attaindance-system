import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signIn(email, password);
    } on FirebaseAuthException catch (e) {
      String msg = '';
      switch (e.code) {
        case 'user-not-found':
          msg = 'No account found for this email. Please Sign Up.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Incorrect password. Please try again.';
          break;
        case 'user-disabled':
          msg = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          msg = 'Too many attempts. Please try again later.';
          break;
        case 'invalid-email':
          msg = 'The email address is not valid.';
          break;
        default:
          msg = 'Login failed (${e.code}). Please try again.';
      }
      if (mounted) setState(() => _errorMessage = msg);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Login error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _forgotPassword() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = "Enter your email to reset your password.");
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Password reset email sent to $email (Demo)"),
        backgroundColor: Colors.orange.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.orange.shade800, Colors.orange.shade500, Colors.orange.shade300],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Professional Logo
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Icon(Icons.fingerprint, size: 60, color: Colors.orange.shade700),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'AttendTrack',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Precision Attendance Tracking',
                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                  ),
                  const SizedBox(height: 40),

                  // Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Welcome Back',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                        const SizedBox(height: 4),
                        Text('Sign in to continue', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        const SizedBox(height: 24),

                        // Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Email
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'you@example.com',
                            prefixIcon: const Icon(Icons.email_outlined, color: Colors.orange),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.orange, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Min. 6 characters',
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.orange),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.orange, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _forgotPassword,
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Login Button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 3,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text('Login', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Demo Access Section
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade100),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                "Quick Access (Example)",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: () {
                                  _emailController.text = "test@lpu.edu.in";
                                  _passwordController.text = "password123";
                                  _login();
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.orange),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text(
                                  "Login as Test Student",
                                  style: TextStyle(color: Colors.orange, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Sign up
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Don't have an account? ", style: TextStyle(color: Colors.grey[600])),
                            GestureDetector(
                               onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SignupScreen()),
                              ),
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
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
          ),
        ),
      ),
    );
  }
}
