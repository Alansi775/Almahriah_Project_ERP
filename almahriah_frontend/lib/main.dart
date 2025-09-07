// lib/main.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/pages/admin_dashboard.dart';
import 'package:almahriah_frontend/pages/employee_dashboard.dart';
import 'package:almahriah_frontend/pages/hr_dashboard.dart';
import 'package:almahriah_frontend/pages/manager_dashboard.dart';
import 'package:almahriah_frontend/pages/login_page.dart';
import 'package:almahriah_frontend/pages/splash_screen.dart';
import 'dart:convert';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:almahriah_frontend/services/auth_service.dart';
import 'package:almahriah_frontend/services/socket_service.dart';
import 'package:flutter/cupertino.dart'; // ✅ تأكد من استيراد هذه المكتبة

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Almahriah TV System',
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [
        Locale('en', ''),
        Locale('ar', 'EG'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: GoogleFonts.almaraiTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: const SplashScreen(),
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
    
    await Future.delayed(const Duration(milliseconds: 1500)); 

    if (token != null && userJson != null) {
      try {
        final isTokenValid = await AuthService.verifyToken(token);

        if (isTokenValid) {
          final user = User.fromJson(json.decode(userJson), token);
          SocketService().initialize(user);
          
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
        } else {
          await prefs.remove('token');
          await prefs.remove('user');
          setState(() {
            _initialWidget = const LoginPage();
          });
        }
      } catch (e) {
        await prefs.remove('token');
        await prefs.remove('user');
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
      return Scaffold( // ❌ تم حذف 'const' من هنا
        body: Center(
          child: CupertinoActivityIndicator(radius: 15.0), // ✅ هذا السطر الآن صحيح
        ),
      );
    } else {
      return _initialWidget!;
    }
  }
}