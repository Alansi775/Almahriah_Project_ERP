// almahriah_frontend/lib/pages/generate_qr_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // 💡 إضافة جديدة
import 'package:qr_flutter/qr_flutter.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/pages/admin_dashboard.dart';

class GenerateQrPage extends StatefulWidget {
  const GenerateQrPage({super.key});

  @override
  State<GenerateQrPage> createState() => _GenerateQrPageState();
}

class _GenerateQrPageState extends State<GenerateQrPage> {
  String? _qrToken;
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _timer; // 💡 إضافة جديدة

  @override
  void initState() {
    super.initState();
    _generateTempQrCode();
  }

  @override
  void dispose() {
    _timer?.cancel(); // 💡 إيقاف المؤقت عند الخروج من الصفحة
    super.dispose();
  }

  Future<void> _generateTempQrCode() async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.65:5050/api/auth/generate-temp-qr'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _qrToken = data['qrToken'];
          _isLoading = false;
        });
        _startPolling(); // 💡 بدء الاستماع
      } else {
        setState(() {
          _errorMessage = json.decode(response.body)['message'] ?? 'فشل في توليد الرمز المؤقت';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ في الاتصال بالخادم: $e';
        _isLoading = false;
      });
    }
  }

  // 💡 دالة جديدة للاستماع لرد الخادم
  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) return;
      try {
        final response = await http.get(
          Uri.parse('http://192.168.1.65:5050/api/auth/check-qr-session?qrToken=$_qrToken'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['user'] != null && data['token'] != null) {
            //  تم تسجيل الدخول!
            timer.cancel(); // إيقاف المؤقت
            if (!mounted) return;

            // توجيه المستخدم إلى لوحة التحكم
            final user = User.fromJson(data['user'], data['token']);
            if (user.role == 'Admin') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => AdminDashboard(user: user)),
              );
            }
          }
        }
      } catch (e) {
        print('Error during polling: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ... (بقية الكود كما هو)
    return Scaffold(
      appBar: AppBar(
        title: Text('تسجيل الدخول بـ QR', style: GoogleFonts.almarai()),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _qrToken != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'امسح الرمز لتسجيل الدخول',
                        style: GoogleFonts.almarai(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 30),
                      QrImageView(
                        data: _qrToken!,
                        version: QrVersions.auto,
                        size: 250.0,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'هذا الرمز صالح لمدة 5 دقائق',
                        style: GoogleFonts.almarai(color: Colors.grey.shade600),
                      ),
                    ],
                  )
                : Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.almarai(color: Colors.red),
                  ),
      ),
    );
  }
}