// almahriah_frontend/lib/pages/login_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:almahriah_frontend/pages/admin_dashboard.dart';
import 'package:almahriah_frontend/pages/employee_dashboard.dart';
import 'package:almahriah_frontend/pages/hr_dashboard.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/pages/manager_dashboard.dart';
import 'package:almahriah_frontend/pages/qr_scanner_page.dart';
import 'package:almahriah_frontend/services/auth_service.dart';
import 'package:almahriah_frontend/widgets/glassmorphism_widgets.dart';
import 'package:flutter/services.dart'; // 💡 استيراد مكتبة الخدمات

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

  void _login() async {
    setState(() {
      _errorMessage = '';
    });

    try {
      final user = await AuthService.login(
        _usernameController.text,
        _passwordController.text,
      );
      
      // ⚡ عند النجاح: اهتزاز قوي ومحدد
      HapticFeedback.heavyImpact();

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
    } catch (e) {
      if (mounted) {
        // ⚡ عند الفشل: اهتزاز للإشارة إلى وجود خطأ
        HapticFeedback.vibrate(); // أو HapticFeedback.heavyImpact()
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0), // تم تقليل الـ padding
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min, // هذا هو المفتاح: يجعل الـ Column يأخذ أقل مساحة ممكنة
                children: [
                  const SizedBox(height: 20), // إضافة مساحة فارغة في الأعلى
                  Text(
                    'أهلاً بك في نظام المهرية',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.almarai(
                      fontSize: 28, // تم تقليل حجم الخط
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Welcome to Almahriah',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 18, // تم تقليل حجم الخط
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20), // تم تقليل المساحة الفارغة
                  buildGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0), // تم تقليل الـ padding
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Image.asset(
                            'assets/logo.png',
                            height: 60, // تم تقليل حجم الشعار
                          ),
                          const SizedBox(height: 20),
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
                          const SizedBox(height: 15), // تم تقليل المساحة الفارغة
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
                          const SizedBox(height: 25),
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
                          const SizedBox(height: 15),
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
                              'QR Code التسجيل ب',
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