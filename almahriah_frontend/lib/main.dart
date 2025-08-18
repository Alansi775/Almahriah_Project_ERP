// almahriah_frontend/lib/main.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/pages/admin_dashboard.dart';
import 'package:almahriah_frontend/pages/employee_dashboard.dart';
import 'package:almahriah_frontend/pages/hr_dashboard.dart';
import 'package:almahriah_frontend/pages/manager_dashboard.dart';
import 'package:almahriah_frontend/pages/login_page.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Almahriah HR System',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: GoogleFonts.almaraiTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Widget? _initialWidget;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userJson = prefs.getString('user');

    if (token != null && userJson != null) {
      try {
        final user = User.fromJson(json.decode(userJson), token);
        setState(() {
          switch (user.role) {
            case 'Admin':
              _initialWidget = AdminDashboard(user: user);
              break;
            case 'HR':
              _initialWidget = HrDashboard(user: user);
              break;
            case 'Manager':
              _initialWidget = ManagerDashboard(user: user);
              break;
            default:
              _initialWidget = EmployeeDashboard(user: user);
              break;
          }
        });
      } catch (e) {
        // If there is an error parsing the data, go to the login page
        setState(() {
          _initialWidget = const LoginPage();
        });
      }
    } else {
      setState(() {
        _initialWidget = const LoginPage();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialWidget == null) {
      // 🚨 هذا هو الجزء الجديد والمهم
      // عرض شاشة تحميل حتى يتم تحديد الصفحة
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.blue),
        ),
      );
    } else {
      return _initialWidget!;
    }
  }
}