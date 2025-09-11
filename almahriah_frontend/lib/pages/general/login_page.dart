import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:almahriah_frontend/pages/dashboards/admin_dashboard.dart';
import 'package:almahriah_frontend/pages/dashboards/employee_dashboard.dart';
import 'package:almahriah_frontend/pages/dashboards/hr_dashboard.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/pages/dashboards/manager_dashboard.dart';
import 'package:almahriah_frontend/pages/general/qr_scanner_page.dart';
import 'package:almahriah_frontend/services/auth_service.dart';
import 'package:flutter/services.dart';
import 'package:almahriah_frontend/widgets/glassmorphism_widgets.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart'; // ✅ استيراد مكتبة Cupertino

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
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  static const platform = MethodChannel('com.almahriah.app/dialog');

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

  Future<void> _showNativeAlert(String title, String message) async {
    try {
      await platform.invokeMethod('showAlert', {
        'title': title,
        'message': message,
      });
    } on PlatformException catch (e) {
      print("Failed to show native alert: '${e.message}'.");
    }
  }

  // ✅ دالة جديدة لعرض تنبيه Flutter الأنيق على الأندرويد والويب
  Future<void> _showFancyFlutterAlert(String title, String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(title, style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message, style: GoogleFonts.almarai()),
              ],
            ),
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              child: const Text('موافق', style: TextStyle(color: CupertinoColors.activeBlue)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _login() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    try {
      final user = await AuthService.login(
        _usernameController.text,
        _passwordController.text,
      );
      
      HapticFeedback.heavyImpact();

      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
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
        setState(() {
          _isLoading = false;
        });
        HapticFeedback.vibrate();
        String errorMessage = e.toString().replaceFirst('Exception: ', '');
        
        // ✅ الشرط الجديد لتحديد التنبيه المناسب
        if (kIsWeb || (!kIsWeb && Platform.isAndroid)) {
          _showFancyFlutterAlert('خطأ في تسجيل الدخول', errorMessage);
        } else if (!kIsWeb && Platform.isIOS) {
          _showNativeAlert('خطأ في تسجيل الدخول', errorMessage);
        } else {
          // fallback for other platforms
          _showFancyFlutterAlert('خطأ في تسجيل الدخول', errorMessage);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectionColor = Colors.blue.shade100;
    final selectionHandleColor = Colors.blue.shade800;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          'أهلاً بك في نظام المهرية',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.almarai(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Welcome to Almahriah',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 15,
                                spreadRadius: 2,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Image.asset(
                                  'assets/logo.png',
                                  height: 60,
                                ),
                                const SizedBox(height: 20),
                                TextSelectionTheme(
                                  data: TextSelectionThemeData(
                                    selectionColor: selectionColor,
                                    selectionHandleColor: selectionHandleColor,
                                    cursorColor: Colors.blue.shade600,
                                  ),
                                  child: TextField(
                                    controller: _usernameController,
                                    style: const TextStyle(color: Colors.black87),
                                    textAlign: TextAlign.left,
                                    textDirection: TextDirection.ltr,
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
                                ),
                                const SizedBox(height: 15),
                                TextSelectionTheme(
                                  data: TextSelectionThemeData(
                                    selectionColor: selectionColor,
                                    selectionHandleColor: selectionHandleColor,
                                    cursorColor: Colors.blue.shade600,
                                  ),
                                  child: TextField(
                                    controller: _passwordController,
                                    obscureText: !_isPasswordVisible,
                                    style: const TextStyle(color: Colors.black87),
                                    textAlign: TextAlign.left,
                                    textDirection: TextDirection.ltr,
                                    decoration: InputDecoration(
                                      labelText: 'كلمة المرور',
                                      labelStyle: TextStyle(color: Colors.blue.shade800),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                      prefixIcon: IconButton(
                                        icon: Icon(
                                          _isPasswordVisible
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: Colors.grey.shade600,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _isPasswordVisible = !_isPasswordVisible;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 25),
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
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator.adaptive(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
          ],
        ),
      ),
    );
  }
}