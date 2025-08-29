// lib/services/auth_service.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/pages/login_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:almahriah_frontend/widgets/glassmorphism_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // ✅ عنوان الخادم الموحد
  static const String baseUrl = 'http://192.168.1.67:5050';

  // دالة لتسجيل الدخول بكلمة المرور واسم المستخدم
  static Future<User> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final user = User.fromJson(data['user'], data['token']);
      await _saveUserAndToken(user);
      return user;
    } else {
      final responseBody = json.decode(response.body);
      throw Exception(responseBody['message'] ?? 'فشل تسجيل الدخول');
    }
  }

  // دالة لتسجيل الدخول باستخدام رمز QR
  static Future<User> qrLogin(String qrToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/qr-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'qrToken': qrToken,
      }),
    );

    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      final user = User.fromJson(responseBody['user'], responseBody['token']);
      await _saveUserAndToken(user);
      return user;
    } else {
      final responseBody = json.decode(response.body);
      throw Exception(responseBody['message'] ?? 'فشل تسجيل الدخول باستخدام رمز QR');
    }
  }

  // دالة لتوليد رمز QR
  static Future<void> generateQrCode(BuildContext context, User user) async {
    final uuid = const Uuid().v4();
    final payload = {'userId': user.id, 'uuid': uuid};
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/generate-qr-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
        },
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        final qrToken = json.decode(response.body)['qrToken'];
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: buildGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'رمز QR لتسجيل الدخول',
                        style: GoogleFonts.almarai(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: QrImageView(
                          data: qrToken,
                          version: QrVersions.auto,
                          size: 200.0,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.blue.shade800,
                          ),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.circle,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'إغلاق',
                          style: GoogleFonts.almarai(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      } else {
        if (!context.mounted) return;
        print('Failed to generate QR code. Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              json.decode(response.body)['message'] ?? 'فشل توليد رمز QR',
              style: GoogleFonts.almarai(),
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      print('Error connecting to server: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في الاتصال بالخادم', style: GoogleFonts.almarai()),
        ),
      );
    }
  }

  // دالة تسجيل الخروج
  static Future<void> logout(BuildContext context, int userId) async {
    final url = Uri.parse('$baseUrl/api/auth/logout');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );

    if (response.statusCode == 200) {
      if (!context.mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    } else {
      print('Failed to log out: ${response.body}');
    }
  }

  // دالة لحفظ بيانات المستخدم في التخزين المحلي
  static Future<void> _saveUserAndToken(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', user.token);
    await prefs.setString('user', json.encode(user.toJson()));
  }

  static Future<User?> getAuthenticatedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userJson = prefs.getString('user');
    if (token != null && userJson != null) {
      return User.fromJson(json.decode(userJson), token);
    }
    return null;
  }
}