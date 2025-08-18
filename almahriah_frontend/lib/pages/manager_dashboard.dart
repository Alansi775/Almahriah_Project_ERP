// almahriah_frontend/lib/pages/manager_dashboard.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import 'add_user_page.dart';
import 'manage_users_page.dart';
import 'login_page.dart';
import 'leave_requests_page.dart';
import 'tasks_page.dart';

class ManagerDashboard extends StatefulWidget {
  final User user;
  
  const ManagerDashboard({super.key, required this.user});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.107:5050/api/admin/dashboard-stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _stats = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        print('Failed to fetch dashboard stats: ${response.body}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Failed to fetch dashboard stats: $e');
    }
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

  Widget _buildGlassTag({required String text}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.blue.shade50.withOpacity(0.5),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.blue.shade100.withOpacity(0.4),
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

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, Widget? page, {bool isLogout = false, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: isLogout ? Colors.red.shade400 : Colors.blue.shade400),
      title: Text(title, style: GoogleFonts.almarai(fontWeight: FontWeight.w600, color: Colors.black87)),
      onTap: onTap ?? () {
        if (isLogout) {
          _logout(context, widget.user.id);
        } else if (page != null) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        }
      },
    );
  }

  Widget _buildStatTile(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 30, color: color),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.almarai(fontSize: 14, color: Colors.black54),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _getPieChartSections() {
    if (_stats['usersByDepartment'] == null) {
      return [];
    }

    final List<Color> colors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.teal.shade400,
    ];

    List<dynamic> departments = _stats['usersByDepartment'];
    return departments.map((department) {
      final int index = departments.indexOf(department);
      final Color color = colors[index % colors.length];
      final double value = (department['count'] as int).toDouble();
      final String title = department['department'];

      return PieChartSectionData(
        color: color.withOpacity(0.7),
        value: value,
        title: '$title\n(${value.toInt()})',
        radius: 80,
        titleStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    String initials = widget.user.fullName != null && widget.user.fullName!.isNotEmpty
        ? widget.user.fullName!.split(' ').map((s) => s[0]).join().substring(0, 2).toUpperCase()
        : 'AA';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildGlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFE5E7EB),
                      radius: 30,
                      child: Text(
                        initials,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      widget.user.fullName ?? 'اسم المستخدم',
                      style: GoogleFonts.almarai(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildGlassTag(
                      text: '${widget.user.role} - ${widget.user.department}',
                    ),
                  ],
                ),
              ),
            ),
            _buildDrawerItem(
              context,
              Icons.qr_code_scanner,
              'إنشاء رمز QR للدخول',
              null,
              onTap: () {
                Navigator.pop(context);
                _generateQrCode();
              },
            ),
            _buildDrawerItem(
              context,
              Icons.logout,
              'الخروج',
              null,
              isLogout: true,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200, minWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لوحة تحكم المدير',
                      style: GoogleFonts.almarai(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'مرحباً بك، ${widget.user.fullName}',
                      style: GoogleFonts.almarai(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildGlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الإحصائيات العامة',
                                  style: GoogleFonts.almarai(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                GridView.count(
                                  crossAxisCount: 2,
                                  childAspectRatio: 1.5,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 20,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    _buildStatTile(
                                      'إجمالي المستخدمين',
                                      _stats['totalUsers'].toString(),
                                      Icons.group_outlined,
                                      Colors.blue.shade400,
                                    ),
                                    _buildStatTile(
                                      'مستخدمون نشطون',
                                      _stats['activeUsers'].toString(),
                                      Icons.person_pin_circle_outlined,
                                      Colors.green.shade400,
                                    ),
                                    _buildStatTile(
                                      'مدراء النظام',
                                      _stats['admins'].toString(),
                                      Icons.verified_user_outlined,
                                      Colors.orange.shade400,
                                    ),
                                    _buildStatTile(
                                      'طلبات الإجازة',
                                      _stats['pendingLeaveRequests']?.toString() ?? '0',
                                      Icons.calendar_today,
                                      Colors.purple.shade400,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 40),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'توزيع المستخدمين حسب القسم',
                                  style: GoogleFonts.almarai(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  height: 300,
                                  child: PieChart(
                                    PieChartData(
                                      sections: _getPieChartSections(),
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 60,
                                      borderData: FlBorderData(show: false),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}