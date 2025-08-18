// almahriah_frontend/lib/pages/login_page.dart

import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'admin_dashboard.dart';
import 'employee_dashboard.dart';
import 'hr_dashboard.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/pages/manager_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'qr_scanner_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _errorMessage = '';
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // دالة لحفظ بيانات المستخدم في التخزين المحلي
  Future<void> _saveUserAndToken(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', user.token);
    await prefs.setString('user', json.encode(user.toJson()));
  }

  // دالة تسجيل الدخول
  void _login() async {
    setState(() {
      _errorMessage = '';
    });

    final username = _usernameController.text;
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'الرجاء إدخال جميع الحقول';
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.107:5050/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _usernameController.text,
          'password': _passwordController.text,
        }),
      );

      final responseBody = json.decode(response.body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final user = User.fromJson(data['user'], data['token']);
        
        await _saveUserAndToken(user);

        if (!mounted) return;
        
        // التوجيه إلى لوحة التحكم المناسبة بناءً على الدور
        switch (user.role) {
          case 'Admin':
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AdminDashboard(user: user)),
            );
            break;
          case 'HR':
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HrDashboard(user: user)),
            );
            break;
          case 'Manager':
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => ManagerDashboard(user: user)),
            );
            break;
          default:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => EmployeeDashboard(user: user)),
            );
            break;
        }
      } else {
        setState(() {
          _errorMessage = responseBody['message'] ?? 'فشل تسجيل الدخول';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ في الاتصال بالخادم';
      });
    }
  }

  // 🚨 تم حذف دالة _generateQrCode من هنا
  // لأنه تم نقلها إلى صفحات لوحات التحكم

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'أهلاً بك في نظام المهرية',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.almarai(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Welcome to Almahriah',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(30.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 15,
                          spreadRadius: 5,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Image.asset(
                          'assets/logo.png',
                          height: 80,
                        ),
                        const SizedBox(height: 30),
                        TextField(
                          controller: _usernameController,
                          style: const TextStyle(color: Colors.black87),
                          textAlign: TextAlign.left,
                          textDirection: TextDirection.ltr,
                          cursorColor: Colors.blue.shade600,
                          decoration: InputDecoration(
                            labelText: 'اسم المستخدم',
                            labelStyle: TextStyle(color: Colors.blue.shade800),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.black87),
                          textAlign: TextAlign.left,
                          textDirection: TextDirection.ltr,
                          cursorColor: Colors.blue.shade600,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            labelStyle: TextStyle(color: Colors.blue.shade800),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                        const SizedBox(height: 30),
                        if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                            textStyle: const TextStyle(fontSize: 18, color: Colors.white),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 5,
                          ),
                          onPressed: _login,
                          child: const Text('تسجيل الدخول', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const QrScannerPage()),
                            );
                          },
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                          label: Text(
                            'تسجيل الدخول بـ QR Code',
                            style: GoogleFonts.almarai(color: Colors.black87),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: const BorderSide(color: Colors.blue),
                          ),
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