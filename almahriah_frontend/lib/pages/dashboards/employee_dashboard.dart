import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart' as intl;
import 'package:almahriah_frontend/pages/leaves/submit_leave_request_page.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/pages/leaves/leave_calendar_page.dart';
import 'package:flutter/services.dart';
import 'package:almahriah_frontend/services/auth_service.dart';
import 'package:almahriah_frontend/widgets/glassmorphism_widgets.dart';
import 'package:almahriah_frontend/widgets/dashboard_widgets.dart' as dashboard_widgets;
import 'package:almahriah_frontend/pages/tasks/task_details_page.dart';
import 'package:almahriah_frontend/pages/general/ai.dart';
import 'package:almahriah_frontend/widgets/animated_ai_button.dart';
import 'package:almahriah_frontend/widgets/task_progress_indicator.dart';
import 'package:almahriah_frontend/pages/chat/chat_list_page.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:almahriah_frontend/pages/general/image_picker_page.dart';
import 'package:almahriah_frontend/services/profile_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // ✅ متغير منفصل لصورة الملف الشخصي
  String? _currentProfilePictureUrl;

  static const platform = MethodChannel('com.almahriah.app/dialog');

  @override
  void initState() {
    super.initState();
    // ✅ تهيئة الصورة عند بدء التشغيل
    _currentProfilePictureUrl = widget.user.profilePictureUrl;
    _fetchData();
  }

  Future<void> _fetchData() async {
    HapticFeedback.lightImpact();
    await Future.wait([
      _fetchEmployeeLeaveRequests(),
      _fetchEmployeeTasks(),
      // ✅ استدعاء دالة تحديث الصورة
      _updateUserProfilePicture(),
    ]);
  }

  String _getInitials(String? fullName) {
    if (fullName == null || fullName.isEmpty) {
      return '';
    }
    final parts = fullName.split(' ');
    if (parts.length > 1) {
      return parts[0][0].toUpperCase() + parts.last[0].toUpperCase();
    }
    return fullName[0].toUpperCase();
  }

  // ✅ دالة مشتركة لعرض التنبيهات
  void _showAlert(String title, String message) {
    if (kIsWeb || (!kIsWeb && Platform.isAndroid)) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: Text(title, style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
            content: Text(message, style: GoogleFonts.almarai()),
            actions: [
              CupertinoDialogAction(
                child: const Text('موافق', style: TextStyle(color: CupertinoColors.activeBlue)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } else if (!kIsWeb && Platform.isIOS) {
      try {
        platform.invokeMethod('showAlert', {
          'title': title,
          'message': message,
        });
      } on PlatformException catch (e) {
        print("Failed to show native alert: '${e.message}'.");
      }
    }
  }

  // ✅ دالة لتحديث صورة المستخدم من الخادم
  Future<void> _updateUserProfilePicture() async {
    try {
      final userResponse = await http.get(
        Uri.parse('http://192.168.1.78:5050/api/admin/users/${widget.user.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}',
        },
      );

      if (userResponse.statusCode == 200) {
        final userData = json.decode(userResponse.body);
        if (mounted) {
          setState(() {
            _currentProfilePictureUrl = userData['profilePictureUrl'] != null 
              ? 'http://192.168.1.78:5050${userData['profilePictureUrl']}'
              : null;
          });
        }
      }
    } catch (e) {
      print('خطأ في تحديث صورة المستخدم: $e');
    }
  }

  Future<void> _fetchEmployeeLeaveRequests() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLeaveRequests = true;
      _leaveMessage = '';
    });

    try {
      final url = Uri.parse('http://192.168.1.78:5050/api/admin/leave-requests/employee/${widget.user.id}');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.user.token}',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _leaveRequests = json.decode(response.body);
          _isLoadingLeaveRequests = false;
        });
      } else {
        if (!mounted) return;
        final responseBody = json.decode(response.body);
        _showAlert('فشل جلب الطلبات', 'فشل جلب الطلبات: ${responseBody['message'] ?? 'خطأ غير معروف'}');
        setState(() {
          _isLoadingLeaveRequests = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showAlert('خطأ في الاتصال', 'حدث خطأ في الاتصال بالخادم: $e');
      setState(() {
        _isLoadingLeaveRequests = false;
      });
    }
  }

  Future<void> _fetchEmployeeTasks() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTasks = true;
      _taskMessage = '';
    });

    try {
      final url = Uri.parse('http://192.168.1.78:5050/api/tasks/by-user');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.user.token}',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _tasks = json.decode(response.body);
          _isLoadingTasks = false;
        });
      } else {
        if (!mounted) return;
        final responseBody = json.decode(response.body);
        _showAlert('فشل جلب المهام', 'فشل جلب المهام: ${responseBody['message'] ?? 'خطأ غير معروف'}');
        setState(() {
          _isLoadingTasks = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showAlert('خطأ في الاتصال', 'حدث خطأ في الاتصال بالخادم: $e');
      setState(() {
        _isLoadingTasks = false;
      });
    }
  }

  Future<void> _updateTaskStatus(dynamic task, String newStatus) async {
    if (task == null || task['id'] == null) {
      if (!mounted) return;
      _showAlert('خطأ', 'معلومات المهمة غير متوفرة.');
      return;
    }

    final String taskId = task['id'].toString();

    try {
      final url = Uri.parse('http://192.168.1.78:5050/api/tasks/$taskId/status');

      Map<String, dynamic> body = {'status': newStatus};
      if (newStatus == 'completed') {
        body['completedAt'] = DateTime.now().toUtc().toIso8601String();
      } else if (newStatus == 'canceled') {
        body['canceledAt'] = DateTime.now().toUtc().toIso8601String();
      } else if (newStatus == 'in_progress') {
        body['inProgressAt'] = DateTime.now().toUtc().toIso8601String();
      }

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          final taskIndex = _tasks.indexWhere((t) => t['id'] == task['id']);
          if (taskIndex != -1) {
            _tasks[taskIndex]['status'] = newStatus;
          }
        });
      } else {
        if (!mounted) return;
        final responseBody = json.decode(response.body);
        _showAlert('فشل التحديث', 'فشل تحديث حالة المهمة: ${responseBody['message'] ?? 'خطأ غير معروف'}');
      }
    } catch (e) {
      if (!mounted) return;
      _showAlert('خطأ في الاتصال', 'حدث خطأ في الاتصال بالخادم: $e');
    }
  }

  String _formatDate(String? date) {
    if (date == null) return 'غير محدد';
    try {
      return intl.DateFormat('yyyy-MM-dd').format(DateTime.parse(date).toLocal());
    } catch (e) {
      return 'تاريخ غير صالح';
    }
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null) {
      return 'غير محدد';
    }
    try {
      final date = DateTime.parse(dateString).toLocal();
      return intl.DateFormat('yyyy/MM/dd – HH:mm').format(date);
    } catch (e) {
      return 'تاريخ غير صالح';
    }
  }

  Color _getStatusColor(String? status) {
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

  String _getLeaveStatusText(String? status) {
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

  String _getTaskStatusText(String? status) {
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

  Color _getTaskStatusColor(String? status) {
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

  Color _getPriorityColor(String? priority) {
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
    String initials = _getInitials(widget.user.fullName);
    final bool isLoading = _isLoadingTasks || _isLoadingLeaveRequests;
    final bool isIOS = kIsWeb ? false : Platform.isIOS;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Image.asset(
          'assets/logo.png',
          height: 35,
        ),
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ),
          actions: [
           //  إضافة أيقونة المحادثة
          IconButton(
            icon: Icon(
              CupertinoIcons.chat_bubble_2_fill,
              color: Colors.blue.shade800,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatListPage(user: widget.user)
                ),
              );
            },
          ),
          if (kIsWeb)
            IconButton(
              icon: Icon(
                Icons.refresh,
                color: Colors.blue.shade800,
              ),
              onPressed: _fetchData,
            ),
        ],
      ),
      extendBodyBehindAppBar: false,
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: buildGlassCard(
                  boxShadow: BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 5),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ تم استبدال CircleAvatar القديم بهذا الكود
                      GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImagePickerPage(user: widget.user),
                            ),
                          );
                          
                          if (result == true && mounted) {
                            // تحديث بيانات المستخدم بعد رفع الصورة
                            await _updateUserProfilePicture();
                            _showAlert('نجاح', 'تم تحديث صورة الملف الشخصي.');
                          }
                        },
                        onLongPress: () async {
                          await handleProfileImageDelete(context, widget.user);
                          await _updateUserProfilePicture();
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFFE5E7EB),
                                radius: 30,
                                backgroundImage: _currentProfilePictureUrl != null
                                    ? NetworkImage(_currentProfilePictureUrl!)
                                    : null,
                                child: _currentProfilePictureUrl == null
                                    ? Text(
                                        initials,
                                        style: GoogleFonts.almarai(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade800,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade600,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        widget.user.fullName ?? 'مستخدم',
                        style: GoogleFonts.almarai(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildGlassTag(
                        text: '${widget.user.role ?? 'غير محدد'} - ${widget.user.department ?? 'غير محدد'}',
                      ),
                    ],
                  ),
                ),
              ),
              dashboard_widgets.buildDrawerItem(
                context,
                Icons.qr_code_scanner,
                'إنشاء رمز QR للدخول',
                null,
                onTap: () {
                  Navigator.pop(context);
                  AuthService.generateQrCode(context, widget.user);
                },
              ),
              dashboard_widgets.buildDrawerItem(
                context,
                Icons.logout,
                'الخروج',
                null,
                isLogout: true,
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
      body: isLoading
          ? Center(
              child: isIOS
                  ? const CupertinoActivityIndicator(radius: 20)
                  : const CircularProgressIndicator(),
            )
          : isIOS
              ? CupertinoScrollbar(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: <Widget>[
                      CupertinoSliverRefreshControl(
                        onRefresh: _fetchData,
                      ),
                      SliverToBoxAdapter(
                        child: _buildBodyContent(context),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  child: SingleChildScrollView(
                    child: _buildBodyContent(context),
                  ),
                ),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 800,
              child: buildGlassCard(
                boxShadow: BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أهلاً بك، ${widget.user.fullName ?? 'مستخدم'}',
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
                        buildGlassTag(text: 'الدور: ${widget.user.role ?? 'غير محدد'}'),
                        buildGlassTag(text: 'القسم: ${widget.user.department ?? 'غير محدد'}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: 800,
              child: dashboard_widgets.buildSectionTitle('الإجراءات السريعة'),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: 800,
              child: Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _buildGlassActionButton(
                    context,
                    title: 'تقديم طلب إجازة جديد',
                    icon: Icons.add_task,
                    color: Colors.blue.shade800,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubmitLeaveRequestPage(user: widget.user),
                        ),
                      );
                    },
                  ),
                  _buildGlassActionButton(
                    context,
                    title: 'عرض تقويم الإجازات',
                    icon: Icons.calendar_today,
                    color: Colors.green.shade700,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LeaveCalendarPage(user: widget.user),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: 800,
              child: dashboard_widgets.buildSectionTitle('مهامي'),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: 800,
              child: _tasks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          _taskMessage.isNotEmpty ? _taskMessage : 'لا توجد مهام مسندة إليك حاليًا.',
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
                        return _buildTaskCard(context, task);
                      },
                    ),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: 800,
              child: dashboard_widgets.buildSectionTitle('طلبات الإجازة الخاصة بي'),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: 800,
              child: _leaveRequests.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          _leaveMessage.isNotEmpty ? _leaveMessage : 'لم يتم تقديم أي طلبات إجازة حتى الآن.',
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
    );
  }

  Widget _buildGlassActionButton(BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 380,
      child: GestureDetector(
        onTap: onTap,
        child: GlassmorphismContainer(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          sigmaX: 10,
          sigmaY: 10,
          color: Colors.white.withOpacity(0.2),
          boxShadow: BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
            child: Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.almarai(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, dynamic task) {
    final statusColor = _getTaskStatusColor(task['status'] as String?);
    final statusText = _getTaskStatusText(task['status'] as String?);
    final priorityColor = _getPriorityColor(task['priority'] as String?);

    String statusDateLabel = '';
    String statusDateValue = '';

    if (task['completedAt'] != null) {
      statusDateLabel = 'تاريخ الانتهاء';
      statusDateValue = _formatDateTime(task['completedAt'] as String?);
    } else if (task['canceledAt'] != null) {
      statusDateLabel = 'تاريخ الإلغاء';
      statusDateValue = _formatDateTime(task['canceledAt'] as String?);
    } else if (task['inProgressAt'] != null) {
      statusDateLabel = 'تاريخ البدء';
      statusDateValue = _formatDateTime(task['inProgressAt'] as String?);
    } else {
      statusDateLabel = 'تاريخ الإسناد';
      statusDateValue = _formatDateTime(task['createdAt'] as String?);
    }

    final String creationDateLabel = 'تاريخ الإسناد';
    final String creationDateValue = _formatDateTime(task['createdAt'] as String?);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () async {
          if (task['id'] != null) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TaskDetailsPage(task: task),
              ),
            );
            if (result == true) {
              _fetchData();
            }
          }
        },
        child: buildGlassCard(
          boxShadow: BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  buildGlassTag(text: statusText, color: statusColor),
                  buildGlassTag(text: task['priority'] as String? ?? 'عادي', color: priorityColor),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                task['title'] as String? ?? 'عنوان غير متوفر',
                style: GoogleFonts.almarai(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                task['description'] as String? ?? 'وصف غير متوفر',
                style: GoogleFonts.almarai(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 15),
              Divider(color: Colors.black.withOpacity(0.1)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(creationDateLabel, style: GoogleFonts.almarai(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text(
                        creationDateValue,
                        style: GoogleFonts.almarai(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(statusDateLabel, style: GoogleFonts.almarai(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text(
                        statusDateValue,
                        style: GoogleFonts.almarai(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _buildTaskActionButtons(task),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskActionButtons(dynamic task) {
    final String currentStatus = task['status'] as String? ?? 'not_started';

    if (currentStatus == 'completed' || currentStatus == 'canceled') {
      return Container();
    }

    return AnimatedTaskProgressIndicator(
      currentStatus: currentStatus,
      onStatusChange: (newStatus) {
        _updateTaskStatus(task, newStatus);
      },
    );
  }

  Widget _buildLeaveRequestCard(dynamic request, Color statusColor, String statusText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: buildGlassCard(
        boxShadow: BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          spreadRadius: 2,
          offset: const Offset(0, 5),
        ),
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
          trailing: buildGlassTag(
            text: statusText,
            color: statusColor,
          ),
        ),
      ),
    );
  }
}