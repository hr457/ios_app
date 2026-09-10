import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_colors.dart';
import '../services/auth_service.dart';
import 'main_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (_mobileController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() {
      _isLoading = true;
      _isSyncing = false;
    });

    // ORIGINAL WORKING URL LIST
    final urls = [
      'http://103.207.168.245/safl/api/logins',
      'http://103.207.168.245/safl/public/api/logins',
      'http://103.207.168.245/safl/api/users/logins',
      'http://103.207.168.245/safl/public/api/users/logins',
      'http://103.207.168.245/safl/api/users', 
      'http://103.207.168.245/safl/api/login',
    ];

    String? errorMessage;
    bool success = false;
    final String loginId = _mobileController.text.trim();
    final String password = _passwordController.text;

    for (String url in urls) {
      try {
        debugPrint("Trying Login URL: $url");
        
        // SIMPLE JSON PAYLOAD (Original Version)
        var response = await http.post(
          Uri.parse(url),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': loginId,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 10));

        // Form Strategy Fallback (Original logic for 405/404)
        if (response.statusCode == 405 || response.statusCode == 415 || response.statusCode == 404) {
           response = await http.post(
            Uri.parse(url),
            headers: {'Accept': 'application/json'},
            body: {
              'email': loginId,
              'password': password,
            },
          ).timeout(const Duration(seconds: 10));
        }

        if (response.statusCode == 200 && response.body.contains('{')) {
          final data = jsonDecode(response.body);
          if (data['status'] == true) {
            final prefs = await SharedPreferences.getInstance();
            final token = data['token'] ?? data['api_token'];
            final userData = data['data'] ?? data['user'];

            await prefs.setString('api_token', token.toString());
            await prefs.setString('user_data', jsonEncode(userData));
            await prefs.setBool('is_logged_in', true);
            debugPrint("Initial Login Success. User: ${userData['name']}");

            // MANDATORY ROLE SYNC: Wait for full profile from Users API
            setState(() {
              _isLoading = false;
              _isSyncing = true;
            });

            try {
              final fullUser = await AuthService.getUserData(forceRefresh: true).timeout(const Duration(seconds: 15));
              if (fullUser != null) {
                debugPrint("Role Sync Complete: ${fullUser.role}");
              }
            } catch (e) {
              debugPrint("Profile sync timeout/error: $e");
            }

            success = true;
            if (!mounted) return;
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainPage()));
            break; 
          } else {
            errorMessage = data['message'];
          }
        }
      } catch (e) {
        debugPrint("Error testing $url: $e");
      }
    }

    if (!success && mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage ?? 'Login failed. Please verify credentials.'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlue,
      body: Stack(
        children: [
          // Background Header
          Container(
            height: MediaQuery.of(context).size.height * 0.6,
            width: double.infinity,
            decoration: const BoxDecoration(gradient: mainGradient),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.asset('assets/logo/setialogo.jfif', height: 60, width: 60, fit: BoxFit.contain)
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Welcome to", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                  const Text("SAFL BUSINESS", style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  const Text("Smart Collection\nBetter Recovery", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  // Calendar/Illustration Placeholder
                  Container(
                    height: 200,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          bottom: 0,
                          child: Container(
                            height: 140, width: 140,
                            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                        const Icon(Icons.calendar_today_rounded, size: 80, color: Colors.white),
                        const Positioned(right: 60, top: 40, child: Icon(Icons.currency_rupee_rounded, color: Colors.amber, size: 40)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
          // Login Form
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.45,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Login to Continue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textHeading)),
                    const SizedBox(height: 24),
                    _inputField(_mobileController, Icons.phone_android_rounded, "Enter Mobile Number"),
                    const SizedBox(height: 16),
                    _inputField(_passwordController, Icons.lock_outline_rounded, "Enter Password", isPassword: true),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: () {}, child: const Text("Forgot Password?", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 12))),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _isSyncing) ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 0,
                        ),
                        child: (_isLoading || _isSyncing) 
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
                                if (_isSyncing) ...[
                                  const SizedBox(width: 12),
                                  const Text("Syncing Profile...", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                ]
                              ],
                            )
                          : const Text("Login", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(child: Text("Version 1.0.0", style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, IconData icon, String hint, {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(color: bodyBg, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.black.withValues(alpha: 0.05))),
      child: TextField(
        controller: ctrl,
        obscureText: isPassword && _obscurePassword,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600),
          prefixIcon: Icon(icon, color: primaryBlue, size: 20),
          suffixIcon: isPassword ? IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: textMuted, size: 20), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}
