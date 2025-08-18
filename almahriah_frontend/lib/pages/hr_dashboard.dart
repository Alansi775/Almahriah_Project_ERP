// almahriah_frontend/lib/pages/hr_dashboard.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:almahriah_frontend/pages/login_page.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/pages/leave_requests_page.dart';
import 'package:almahriah_frontend/pages/leave_history_page.dart';
import 'package:almahriah_frontend/pages/employee_list_page.dart';
import 'package:almahriah_frontend/pages/tasks_page.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

class AcceptedLeaveRequestsPage extends StatelessWidget {
  final User user;
  const AcceptedLeaveRequestsPage({Key? key, required this.user}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('الإجازات المقبولة', style: GoogleFonts.almarai())),
      body: Center(child: Text('هنا ستظهر جميع الإجازات المقبولة')),
    );
  }
}

class HrDashboard extends StatefulWidget {
  final User user;
  
  const HrDashboard({super.key, required this.user});

  @override
  State<HrDashboard> createState() => _HrDashboardState();
}

class _HrDashboardState extends State<HrDashboard> {
  Widget _buildGlassCard({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGlassTag({required String text, Color? color}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (color ?? Colors.blue.shade50).withOpacity(0.5),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: (color ?? Colors.blue.shade100).withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: Text(
            text,
            style: GoogleFonts.almarai(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  void _logout(BuildContext context, int userId) async {
    final url = Uri.parse('http://192.168.1.107:5050/api/auth/logout');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );

    if (response.statusCode == 200) {
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } else {
      print('Failed to log out: ${response.body}');
    }
  }
  
  void _generateQrCode() async {
    final uuid = const Uuid().v4();
    final payload = {'userId': widget.user.id, 'uuid': uuid};
    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.107:5050/api/auth/generate-qr-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final qrToken = json.decode(response.body)['qrToken'];
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: _buildGlassCard(
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
        if (!mounted) return;
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
      if (!mounted) return;
      print('Error connecting to server: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في الاتصال بالخادم', style: GoogleFonts.almarai()),
        ),
      );
    }
  }
  
  Widget _buildGlassButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(15),
      child: _buildGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.almarai(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Image.asset(
          'assets/logo.png',
          height: 35,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: SizedBox(
            width: 700,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'أهلاً بك، ${widget.user.fullName}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.almarai(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 5),
                _buildGlassTag(text: 'دورك: ${widget.user.role} - ${widget.user.department}'),
                const SizedBox(height: 30),
                _buildGlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'لوحة التحكم',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.almarai(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 15,
                        runSpacing: 15,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildGlassButton(
                            context: context,
                            label: 'طلبات الإجازة المعلقة',
                            icon: Icons.pending_actions,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LeaveRequestsPage(user: widget.user),
                                ),
                              );
                            },
                            color: Colors.orange.shade800,
                          ),
                          _buildGlassButton(
                            context: context,
                            label: 'سجل الإجازات',
                            icon: Icons.history,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LeaveHistoryPage(user: widget.user),
                                ),
                              );
                            },
                            color: Colors.blue.shade800,
                          ),
                          _buildGlassButton(
                            context: context,
                            label: 'قائمة الموظفين',
                            icon: Icons.person_add_alt_1,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EmployeeListPage(user: widget.user),
                                ),
                              );
                            },
                            color: Colors.teal.shade800,
                          ),
                          _buildGlassButton(
                            context: context,
                            label: 'المهام والمشاريع',
                            icon: Icons.task_alt,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TasksPage(user: widget.user),
                                ),
                              );
                            },
                            color: Colors.purple.shade800,
                          ),
                          _buildGlassButton(
                            context: context,
                            label: 'إنشاء رمز QR للدخول',
                            icon: Icons.qr_code_scanner,
                            onPressed: _generateQrCode,
                            color: Colors.green.shade800,
                          ),
                          _buildGlassButton(
                            context: context,
                            label: 'تسجيل الخروج',
                            icon: Icons.exit_to_app,
                            onPressed: () => _logout(context, widget.user.id),
                            color: Colors.red.shade800,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}