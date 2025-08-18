// almahriah_frontend/lib/pages/employee_dashboard.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:intl/intl.dart' as intl;
import 'package:almahriah_frontend/pages/login_page.dart';
import 'package:almahriah_frontend/pages/submit_leave_request_page.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/pages/leave_calendar_page.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

class EmployeeDashboard extends StatefulWidget {
  final User user;

  const EmployeeDashboard({super.key, required this.user});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  List _leaveRequests = [];
  bool _isLoadingLeaveRequests = true;
  String _leaveMessage = '';

  List _tasks = [];
  bool _isLoadingTasks = true;
  String _taskMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchEmployeeLeaveRequests();
    _fetchEmployeeTasks();
  }

  Future<void> _fetchEmployeeLeaveRequests() async {
    setState(() {
      _isLoadingLeaveRequests = true;
      _leaveMessage = '';
    });

    try {
      final url = Uri.parse('http://192.168.1.107:5050/api/admin/leave-requests/employee/${widget.user.id}');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.user.token}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _leaveRequests = json.decode(response.body);
          _isLoadingLeaveRequests = false;
        });
      } else {
        setState(() {
          _leaveMessage = 'فشل جلب الطلبات: ${json.decode(response.body)['message']}';
          _isLoadingLeaveRequests = false;
        });
      }
    } catch (e) {
      setState(() {
        _leaveMessage = 'حدث خطأ في الاتصال بالخادم: $e';
        _isLoadingLeaveRequests = false;
      });
    }
  }

  Future<void> _fetchEmployeeTasks() async {
    setState(() {
      _isLoadingTasks = true;
      _taskMessage = '';
    });

    try {
      final url = Uri.parse('http://192.168.1.107:5050/api/tasks/by-user');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.user.token}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _tasks = json.decode(response.body);
          _isLoadingTasks = false;
        });
      } else {
        setState(() {
          _taskMessage = 'فشل جلب المهام: ${json.decode(response.body)['message']}';
          _isLoadingTasks = false;
        });
      }
    } catch (e) {
      setState(() {
        _taskMessage = 'حدث خطأ في الاتصال بالخادم: $e';
        _isLoadingTasks = false;
      });
    }
  }

  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    try {
      final url = Uri.parse('http://192.168.1.107:5050/api/tasks/$taskId/status');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث حالة المهمة بنجاح!', style: GoogleFonts.almarai()),
          ),
        );
        _fetchEmployeeTasks();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل تحديث حالة المهمة: ${json.decode(response.body)['message']}',
              style: GoogleFonts.almarai(),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في الاتصال بالخادم: $e', style: GoogleFonts.almarai()),
        ),
      );
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
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
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

  String _formatDate(String date) {
    return intl.DateFormat('yyyy-MM-dd').format(DateTime.parse(date));
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Accepted':
        return Colors.green.shade600;
      case 'Rejected':
        return Colors.red.shade600;
      case 'Pending':
      default:
        return Colors.orange.shade600;
    }
  }

  String _getLeaveStatusText(String status) {
    switch (status) {
      case 'Accepted':
        return 'مقبول';
      case 'Rejected':
        return 'مرفوض';
      case 'Pending':
      default:
        return 'قيد الانتظار';
    }
  }

  String _getTaskStatusText(String status) {
    switch (status) {
      case 'pending':
      case 'not_started':
        return 'لم تبدأ بعد';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'completed':
        return 'مكتملة';
      case 'canceled':
        return 'ملغاة';
      default:
        return 'غير معروف';
    }
  }

  Color _getTaskStatusColor(String status) {
    switch (status) {
      case 'pending':
      case 'not_started':
        return Colors.grey.shade600;
      case 'in_progress':
        return Colors.blue.shade600;
      case 'completed':
        return Colors.green.shade600;
      case 'canceled':
        return Colors.red.shade600;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'عاجل':
        return Colors.red.shade600;
      case 'مهم':
        return Colors.orange.shade600;
      case 'عادي':
      default:
        return Colors.blue.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        title: Image.asset(
          'assets/logo.png',
          height: 35,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: () {
              _fetchEmployeeLeaveRequests();
              _fetchEmployeeTasks();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => _logout(context, widget.user.id),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Text(
                'لوحة تحكم',
                style: GoogleFonts.almarai(color: Colors.white, fontSize: 24),
              ),
            ),
            // Menu Items
            ListTile(
              leading: const Icon(Icons.qr_code_scanner, color: Colors.green),
              title: Text('إنشاء رمز QR للدخول', style: GoogleFonts.almarai(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                _generateQrCode();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text('الخروج', style: GoogleFonts.almarai(fontWeight: FontWeight.w600)),
              onTap: () => _logout(context, widget.user.id),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 800,
                child: _buildGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أهلاً بك، ${widget.user.fullName}',
                        style: GoogleFonts.almarai(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'مرحباً بك في لوحة تحكم الموظف. هنا يمكنك إدارة مهامك وطلبات الإجازات الخاصة بك.',
                        style: GoogleFonts.almarai(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildGlassTag(text: 'الدور: ${widget.user.role}'),
                          _buildGlassTag(text: 'القسم: ${widget.user.department}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: 800,
                child: _buildSectionTitle('الإجراءات السريعة'),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: 800,
                child: Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    SizedBox(
                      width: 380,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubmitLeaveRequestPage(user: widget.user),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_task, color: Colors.white, size: 28),
                        label: Text(
                          'تقديم طلب إجازة جديد',
                          style: GoogleFonts.almarai(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 5,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 380,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LeaveCalendarPage(user: widget.user),
                            ),
                          );
                        },
                        icon: Icon(Icons.calendar_today, color: Colors.blue.shade800, size: 28),
                        label: Text(
                          'عرض تقويم الإجازات',
                          style: GoogleFonts.almarai(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          side: BorderSide(
                            color: Colors.blue.shade800,
                            width: 2,
                          ),
                          elevation: 5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: 800,
                child: _buildSectionTitle('مهامي'),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: 800,
                child: _isLoadingTasks
                    ? const Center(child: CircularProgressIndicator())
                    : _tasks.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                'لا توجد مهام مسندة إليك حاليًا.',
                                style: GoogleFonts.almarai(fontSize: 16, color: Colors.black54),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _tasks.length,
                            itemBuilder: (context, index) {
                              final task = _tasks[index];
                              return _buildTaskCard(task);
                            },
                          ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: 800,
                child: _buildSectionTitle('طلبات الإجازة الخاصة بي'),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: 800,
                child: _isLoadingLeaveRequests
                    ? const Center(child: CircularProgressIndicator())
                    : _leaveRequests.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                'لم يتم تقديم أي طلبات إجازة حتى الآن.',
                                style: GoogleFonts.almarai(fontSize: 16, color: Colors.black54),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _leaveRequests.length,
                            itemBuilder: (context, index) {
                              final request = _leaveRequests[index];
                              final statusColor = _getStatusColor(request['status']);
                              final statusText = _getLeaveStatusText(request['status']);
                              return _buildLeaveRequestCard(request, statusColor, statusText);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.almarai(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }

  Widget _buildTaskCard(dynamic task) {
    final statusColor = _getTaskStatusColor(task['status']);
    final statusText = _getTaskStatusText(task['status']);
    final priorityColor = _getPriorityColor(task['priority']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGlassTag(text: statusText, color: statusColor),
                _buildGlassTag(text: task['priority'], color: priorityColor),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              task['title'],
              style: GoogleFonts.almarai(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              task['description'],
              style: GoogleFonts.almarai(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 15),
            _buildTaskActionButtons(task),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskActionButtons(dynamic task) {
    List<Widget> buttons = [];
    final String currentStatus = task['status'];
    final String taskId = task['id'].toString();

    if (currentStatus == 'not_started' || currentStatus == 'pending') {
      buttons.add(
        Expanded(
          child: ElevatedButton(
            onPressed: () => _updateTaskStatus(taskId, 'in_progress'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: Text(
              'بدء المهمة',
              style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }
    
    if (currentStatus == 'in_progress') {
      buttons.add(
        Expanded(
          child: ElevatedButton(
            onPressed: () => _updateTaskStatus(taskId, 'completed'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: Text(
              'مكتملة',
              style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
      buttons.add(const SizedBox(width: 10));
      buttons.add(
        Expanded(
          child: ElevatedButton(
            onPressed: () => _updateTaskStatus(taskId, 'canceled'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: Text(
              'إلغاء',
              style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    if (buttons.isEmpty) {
      return Container();
    }

    return Row(children: buttons);
  }

  Widget _buildLeaveRequestCard(dynamic request, Color statusColor, String statusText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildGlassCard(
        padding: const EdgeInsets.all(15),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.2),
            child: Icon(
              request['status'] == 'Accepted' ? Icons.check_circle :
              request['status'] == 'Rejected' ? Icons.cancel :
              Icons.access_time_filled,
              color: statusColor,
            ),
          ),
          title: Text(
            'طلب إجازة',
            style: GoogleFonts.almarai(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          subtitle: Text(
            'من ${_formatDate(request['startDate'])} إلى ${_formatDate(request['endDate'])}',
            style: GoogleFonts.almarai(color: Colors.black54),
          ),
          trailing: _buildGlassTag(
            text: statusText,
            color: statusColor,
          ),
        ),
      ),
    );
  }
}