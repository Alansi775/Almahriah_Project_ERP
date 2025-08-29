import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/services/auth_service.dart';
import 'package:almahriah_frontend/widgets/glassmorphism_widgets.dart';
import 'package:almahriah_frontend/widgets/dashboard_widgets.dart';
import 'package:flutter/services.dart';
import 'package:almahriah_frontend/custom_page_route.dart';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 

import 'add_user_page.dart';
import 'manage_users_page.dart';
import 'leave_requests_page.dart';
import 'tasks_page.dart';
import 'tasks_list_page.dart'; 
import 'package:almahriah_frontend/pages/ai.dart';
import 'package:almahriah_frontend/widgets/animated_ai_button.dart';
// ✅ استيراد صفحة المحادثات
import 'chat_list_page.dart'; 

class AdminDashboard extends StatefulWidget {
  final User user;
  
  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.67:5050/api/admin/dashboard-stats'),
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
        HapticFeedback.lightImpact();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              json.decode(response.body)['message'] ?? 'فشل تحميل إحصائيات لوحة التحكم',
              style: GoogleFonts.almarai(),
            ),
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في الاتصال بالخادم: $e', style: GoogleFonts.almarai()),
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
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
  
  void _navigateToTasks(String title, String status) {
    HapticFeedback.heavyImpact();
    Navigator.push(
      context,
      CustomPageRoute(
        child: TasksListPage(
          user: widget.user,
          title: title,
          statusFilter: status,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    String initials = widget.user.fullName != null && widget.user.fullName!.isNotEmpty
        ? widget.user.fullName!.split(' ').map((s) => s[0]).join().substring(0, 2).toUpperCase()
        : 'AA';

    final bool isScrolled = _scrollOffset > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: buildGlassCard(
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
                      buildGlassTag(
                        text: '${widget.user.role} - ${widget.user.department}',
                      ),
                    ],
                  ),
                ),
              ),
              // ✅ إضافة أيقونة المحادثة في قائمة المدير
              ListTile(
                  leading: const Icon(CupertinoIcons.chat_bubble_2, color: Colors.blueAccent),
                  title: Text('المحادثات', style: GoogleFonts.almarai()),
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    Navigator.pop(context);
                    Navigator.push(context, CustomPageRoute(child: ChatListPage(user: widget.user)));
                  },
              ),
              if (widget.user.role == 'Admin') ...[
                ListTile(
                  leading: const Icon(Icons.person_add, color: Colors.blueAccent),
                  title: Text('إضافة مستخدم', style: GoogleFonts.almarai()),
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    Navigator.pop(context);
                    Navigator.push(context, CustomPageRoute(child: AddUserPage(user: widget.user)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.manage_accounts, color: Colors.green),
                  title: Text('التحكم في المستخدمين', style: GoogleFonts.almarai()),
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    Navigator.pop(context);
                    Navigator.push(context, CustomPageRoute(child: ManageUsersPage(user: widget.user)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.task, color: Colors.orange),
                  title: Text('إدارة المهام', style: GoogleFonts.almarai()),
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    Navigator.pop(context);
                    Navigator.push(context, CustomPageRoute(child: TasksPage(user: widget.user)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month, color: Colors.purple),
                  title: Text('طلبات الإجازة', style: GoogleFonts.almarai()),
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    Navigator.pop(context);
                    Navigator.push(context, CustomPageRoute(child: LeaveRequestsPage(user: widget.user)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner, color: Colors.teal),
                  title: Text('إنشاء رمز QR للدخول', style: GoogleFonts.almarai()),
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    Navigator.pop(context);
                    AuthService.generateQrCode(context, widget.user);
                  },
                ),
              ] else if (widget.user.role == 'Manager') ...[
                ListTile(
                  leading: const Icon(Icons.task, color: Colors.orange),
                  title: Text('إدارة المهام', style: GoogleFonts.almarai()),
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    Navigator.pop(context);
                    Navigator.push(context, CustomPageRoute(child: TasksPage(user: widget.user)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month, color: Colors.purple),
                  title: Text('طلبات الإجازة', style: GoogleFonts.almarai()),
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    Navigator.pop(context);
                    Navigator.push(context, CustomPageRoute(child: LeaveRequestsPage(user: widget.user)));
                  },
                ),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text('الخروج', style: GoogleFonts.almarai()),
                onTap: () => AuthService.logout(context, widget.user.id),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: AnimatedAiButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AiChatPage(user: widget.user),
            ),
          );
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NotificationListener<ScrollUpdateNotification>(
              onNotification: (ScrollUpdateNotification notification) {
                setState(() {
                  _scrollOffset = notification.metrics.pixels;
                });
                return false;
              },
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverAppBar(
                    expandedHeight: 0,
                    floating: true,
                    pinned: true,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    flexibleSpace: FlexibleSpaceBar(
                      background: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: isScrolled ? 10 : 0,
                            sigmaY: isScrolled ? 10 : 0,
                          ),
                          child: Container(
                            color: isScrolled ? Colors.white.withOpacity(0.8) : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                    leading: Builder(
                      builder: (BuildContext innerContext) {
                        return IconButton(
                          icon: const Icon(Icons.menu, color: Colors.black),
                          onPressed: () => Scaffold.of(innerContext).openDrawer(),
                        );
                      },
                    ),
                    title: Image.asset('assets/logo.png', height: 35),
                    centerTitle: true,
                    actions: [
                      if (kIsWeb)
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.black),
                          onPressed: _fetchDashboardStats,
                        ),
                      IconButton(
                        icon: const Icon(Icons.notifications_none, color: Colors.black),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  if (!kIsWeb)
                    CupertinoSliverRefreshControl(
                      onRefresh: _fetchDashboardStats,
                      builder: (
                        BuildContext context,
                        RefreshIndicatorMode refreshState,
                        double pulledExtent,
                        double refreshTriggerPullDistance,
                        double refreshIndicatorExtent,
                      ) {
                        return CupertinoSliverRefreshControl.buildRefreshIndicator(
                          context,
                          refreshState,
                          pulledExtent,
                          refreshTriggerPullDistance,
                          refreshIndicatorExtent,
                        );
                      },
                    ),
                  SliverToBoxAdapter(
                    child: Center(
                      child: kIsWeb
                          ? ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: 1000,
                              ),
                              child: _buildDashboardContent(),
                            )
                          : _buildDashboardContent(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDashboardContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
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
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = constraints.maxWidth < 600 ? 1 : 2;
              double childAspectRatio = constraints.maxWidth < 600 ? 2.5 : 1.5;
              return GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                children: [
                  buildStatTile(
                    'إجمالي المستخدمين',
                    _stats['totalUsers'].toString(),
                    Icons.group_outlined,
                    Colors.blue.shade400,
                  ),
                  buildStatTile(
                    'مستخدمون نشطون',
                    _stats['activeUsers'].toString(),
                    Icons.person_pin_circle_outlined,
                    Colors.green.shade400,
                  ),
                  buildStatTile(
                    'مدراء النظام',
                    _stats['admins'].toString(),
                    Icons.verified_user_outlined,
                    Colors.orange.shade400,
                  ),
                  buildStatTile(
                    'طلبات الإجازة',
                    _stats['pendingLeaveRequests']?.toString() ?? '0',
                    Icons.calendar_today,
                    Colors.purple.shade400,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          buildGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}