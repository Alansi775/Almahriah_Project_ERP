// almahriah_frontend/lib/pages/qr_scanner_page.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/pages/admin_dashboard.dart';
import 'package:almahriah_frontend/pages/hr_dashboard.dart';
import 'package:almahriah_frontend/pages/manager_dashboard.dart';
import 'package:almahriah_frontend/pages/employee_dashboard.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:almahriah_frontend/pages/login_page.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _handleQrCode(String? qrToken) async {
    if (qrToken == null || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.107:5050/api/auth/qr-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'qrToken': qrToken,
        }),
      );

      final responseBody = json.decode(response.body);

      if (response.statusCode == 200) {
        final user = User.fromJson(responseBody['user'], responseBody['token']);
        
        await _saveUserAndToken(user); 

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseBody['message'] ?? 'تم تسجيل الدخول بنجاح!',
              style: GoogleFonts.almarai(),
            ),
          ),
        );
        controller.stop();
        _navigateToDashboard(user);

      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseBody['message'] ?? 'فشل تسجيل الدخول باستخدام رمز QR',
              style: GoogleFonts.almarai(),
            ),
          ),
        );
        controller.stop();
        controller.start();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في الاتصال بالخادم: $e', style: GoogleFonts.almarai()),
        ),
      );
      controller.stop();
      controller.start();
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveUserAndToken(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', user.token);
    await prefs.setString('user', json.encode(user.toJson()));
  }

  void _navigateToDashboard(User user) {
    Widget page;
    switch (user.role) {
      case 'Admin':
        page = AdminDashboard(user: user);
        break;
      case 'HR':
        page = HrDashboard(user: user);
        break;
      case 'Manager':
        page = ManagerDashboard(user: user);
        break;
      default:
        page = EmployeeDashboard(user: user);
        break;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => page));
  }

  Widget _buildOverlay() {
    return Stack(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.5),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: MediaQuery.of(context).size.width * 0.7,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            height: MediaQuery.of(context).size.width * 0.7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade600, width: 3),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('مسح رمز QR', style: GoogleFonts.almarai(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: <Widget>[
          MobileScanner(
            controller: controller,
            onDetect: (barcode) {
              final String? qrToken = barcode.barcodes.first.rawValue;
              if (qrToken != null && !_isProcessing) {
                _handleQrCode(qrToken);
              }
            },
          ),
          _buildOverlay(),
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            left: 0,
            right: 0,
            child: Text(
              'امسح رمز QR الموجود على شاشة الكمبيوتر',
              textAlign: TextAlign.center,
              style: GoogleFonts.almarai(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 5.0,
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(2.0, 2.0),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  if (!_isProcessing) {
                    controller.start();
                    setState(() {
                      _isProcessing = false;
                    });
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المسح'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}