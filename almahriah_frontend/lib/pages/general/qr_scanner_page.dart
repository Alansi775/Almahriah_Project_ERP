// lib/pages/qr_scanner_page.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/pages/dashboards/admin_dashboard.dart';
import 'package:almahriah_frontend/pages/dashboards/hr_dashboard.dart';
import 'package:almahriah_frontend/pages/dashboards/manager_dashboard.dart';
import 'package:almahriah_frontend/pages/dashboards/employee_dashboard.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:almahriah_frontend/services/auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/cupertino.dart';

//  تعريف قناة التواصل الناتيف
const MethodChannel _dialogChannel = MethodChannel('com.almahriah.app/dialog');

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

  //  دالة جديدة لإرسال الرسائل عبر قنوات التواصل
  Future<void> _showNativeMessage({
    required bool isSuccess,
    required String message,
  }) async {
    //  في iOS، نستخدم قنوات التواصل
    if (!kIsWeb && Platform.isIOS) {
      if (isSuccess) {
        // رسالة نجاح: نستخدم 'showToast'
        await _dialogChannel.invokeMethod('showToast', {'message': message});
        HapticFeedback.lightImpact(); // إضافة نبضة للنجاح
      } else {
        // رسالة خطأ: نستخدم 'showAlert'
        await _dialogChannel.invokeMethod('showAlert', {'title': 'خطأ', 'message': message});
      }
    } else {
      //  في Android أو الويب، نستخدم ScaffoldMessenger
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.almarai()),
          backgroundColor: isSuccess ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _handleQrCode(String? qrToken) async {
    if (qrToken == null || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });
    
    controller.stop();

    try {
      final user = await AuthService.qrLogin(qrToken);

      if (!mounted) return;

      //  عرض الرسالة الناتيف أولاً
      await _showNativeMessage(isSuccess: true, message: 'تم تسجيل الدخول بنجاح!');

      //  نستخدم تأخير بسيط لضمان ظهور الرسالة الناتيف
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;
      _navigateToDashboard(user);

    } catch (e) {
      if (!mounted) return;

      //  عرض رسالة الخطأ الناتيف
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      await _showNativeMessage(isSuccess: false, message: errorMessage);

      // إعادة تشغيل الماسح الضوئي بعد فشل العملية
      controller.start();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
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
        Align(
          alignment: Alignment.center,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOut,
            builder: (BuildContext context, double value, Widget? child) {
              return Transform.scale(
                scale: 1 + value * 0.1,
                child: Opacity(
                  opacity: 1 - value,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    height: MediaQuery.of(context).size.width * 0.7,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.blue.shade600.withOpacity(1 - value),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              );
            },
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('الماسح جاهز لإعادة المسح', style: GoogleFonts.almarai()),
                      ),
                    );
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