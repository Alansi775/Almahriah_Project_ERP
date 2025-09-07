//  Replace the entire content of your tasks_page.dart file with this code.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:almahriah_frontend/pages/add_task_page.dart';
import 'package:almahriah_frontend/pages/task_details_page.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

//  Define the MethodChannel to communicate with native iOS code
const platform = MethodChannel('com.almahriah.app/dialog');

class TasksPage extends StatefulWidget {
  final User user;
  const TasksPage({super.key, required this.user});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  late Future<List<dynamic>> _tasksFuture;
  late Future<List<dynamic>> _departmentsFuture;
  String? _selectedDepartment;

  @override
  void initState() {
    super.initState();
    _refreshData(); // Call refresh on init to load data
  }

  //  New method to call native iOS alerts
  void _showNativeAlert({required String title, required String message}) async {
    if (!kIsWeb) {
      if (Platform.isIOS) {
        try {
          await platform.invokeMethod('showAlert', {'title': title, 'message': message});
        } on PlatformException catch (e) {
          print("Failed to invoke native alert: ${e.message}");
        }
      }
    }
  }

  //  New method to call native iOS toasts
  void _showNativeToast({required String message}) async {
    if (!kIsWeb) {
      if (Platform.isIOS) {
        try {
          await platform.invokeMethod('showToast', {'message': message});
        } on PlatformException catch (e) {
          print("Failed to invoke native toast: ${e.message}");
        }
      } else {
        _showMessage(message: message, isSuccess: true);
      }
    } else {
      _showMessage(message: message, isSuccess: true);
    }
  }

  //  Updated function to handle confirmation dialogs based on platform
  Future<bool?> _showConfirmationDialog({
    required String title,
    required String content,
  }) async {
    if (!kIsWeb && Platform.isIOS) {
      try {
        final result = await platform.invokeMethod('showConfirmationAlert', {
          'title': title,
          'message': content,
        });
        return result as bool?;
      } on PlatformException catch (e) {
        print("Failed to invoke native confirmation alert: ${e.message}");
        return false; // Assume cancellation on failure
      }
    } else {
      return showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title, style: GoogleFonts.almarai()),
            content: Text(content, style: GoogleFonts.almarai()),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('إلغاء', style: GoogleFonts.almarai(color: Colors.black)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('حذف', style: GoogleFonts.almarai(color: Colors.white)),
              ),
            ],
          );
        },
      );
    }
  }

  //  Re-implementing the message display to use the native channel for iOS
  void _showMessage({
    required String message,
    required bool isSuccess,
  }) {
    if (Platform.isIOS) {
      if (isSuccess) {
        _showNativeToast(message: message);
      } else {
        _showNativeAlert(title: 'خطأ', message: message);
      }
    } else {
      //  Use a standard snackbar for Android/Web
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.almarai()),
          backgroundColor: isSuccess ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<List<dynamic>> _fetchDepartments() async {
    final response = await http.get(
      Uri.parse('http://192.168.1.65:5050/api/admin/departments'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.user.token}',
      },
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('فشل جلب الأقسام: ${response.body}');
    }
  }

  Future<List<dynamic>> _fetchTasks({String? department}) async {
    String apiUrl;
    if (widget.user.role == 'Admin') {
      if (department == null) return [];
      apiUrl = 'http://192.168.1.65:5050/api/tasks/by-department?department=$department';
    } else if (widget.user.role == 'Manager') {
      apiUrl = 'http://192.168.1.65:5050/api/tasks/by-department?department=${widget.user.department}';
    } else {
      apiUrl = 'http://192.168.1.65:5050/api/tasks/by-user';
    }

    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.user.token}',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('فشل جلب المهام: ${json.decode(response.body)['message']}');
    }
  }

  Future<void> _refreshData() async {
    HapticFeedback.lightImpact();
    if (widget.user.role == 'Admin' && _selectedDepartment == null) {
      setState(() {
        _departmentsFuture = _fetchDepartments();
      });
    } else {
      setState(() {
        _tasksFuture = _fetchTasks(department: _selectedDepartment);
      });
    }
  }

  Future<void> _deleteAllDepartmentTasks() async {
    HapticFeedback.lightImpact();
    final confirm = await _showConfirmationDialog(
      title: 'تأكيد الحذف',
      content: 'هل أنت متأكد أنك تريد حذف جميع مهام قسمك؟ لا يمكن التراجع عن هذا الإجراء.',
    );

    if (confirm != true) {
      return;
    }

    try {
      final url = Uri.parse('http://192.168.1.65:5050/api/tasks/by-department?department=${widget.user.department}');
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.user.token}',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        _showMessage(
          message: json.decode(response.body)['message'],
          isSuccess: true,
        );
        setState(() {
          _tasksFuture = _fetchTasks();
        });
      } else {
        if (!mounted) return;
        _showMessage(
          message: json.decode(response.body)['message'],
          isSuccess: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        message: 'حدث خطأ في الاتصال بالخادم: $e',
        isSuccess: false,
      );
    }
  }

  Future<void> _deleteTask(String taskId) async {
    HapticFeedback.lightImpact();
    final confirm = await _showConfirmationDialog(
      title: 'تأكيد الحذف',
      content: 'هل أنت متأكد أنك تريد حذف هذه المهمة؟',
    );

    if (confirm != true) {
      return;
    }

    try {
      final url = Uri.parse('http://192.168.1.65:5050/api/tasks/$taskId');
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.user.token}',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        _showMessage(
          message: 'تم حذف المهمة بنجاح!',
          isSuccess: true,
        );
        setState(() {
          _tasksFuture = _fetchTasks(department: _selectedDepartment);
        });
      } else {
        if (!mounted) return;
        _showMessage(
          message: 'فشل حذف المهمة: ${json.decode(response.body)['message']}',
          isSuccess: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        message: 'حدث خطأ في الاتصال بالخادم: $e',
        isSuccess: false,
      );
    }
  }

  void _onDepartmentTapped(String departmentName) {
    setState(() {
      _selectedDepartment = departmentName;
      _tasksFuture = _fetchTasks(department: departmentName);
    });
  }

  Widget _buildGlassCard({required Widget child, EdgeInsets? padding}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.4);
    final borderColor = isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.2);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'in_progress':
        return Colors.orange.shade800;
      case 'completed':
        return Colors.green.shade800;
      case 'pending':
        return Colors.blue.shade800;
      case 'canceled':
        return Colors.red.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  String _mapStatusToArabic(String status) {
    switch (status) {
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'completed':
        return 'مكتمل';
      case 'pending':
      case 'not_started':
        return 'لم تبدأ بعد';
      case 'canceled':
        return 'ملغاة';
      default:
        return 'غير محدد';
    }
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final secondaryTextColor = isDarkMode ? Colors.white70 : Colors.black54;

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailsPage(task: task),
          ),
        );
        if (result == true) {
          _refreshData();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      task['title'] ?? 'لا يوجد عنوان',
                      style: GoogleFonts.almarai(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(task['status'] ?? 'غير محدد').withOpacity(isDarkMode ? 0.4 : 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _mapStatusToArabic(task['status'] ?? 'غير محدد'),
                      style: GoogleFonts.almarai(
                        fontSize: 14,
                        color: _getStatusColor(task['status'] ?? 'غير محدد'),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'المسؤول: ${task['assignedToName'] ?? 'غير محدد'}',
                style: GoogleFonts.almarai(fontSize: 14, color: secondaryTextColor),
              ),
              Text(
                'الأولوية: ${task['priority'] ?? 'غير محدد'}',
                style: GoogleFonts.almarai(fontSize: 14, color: secondaryTextColor),
              ),
              if (widget.user.role == 'Manager' || widget.user.role == 'Admin')
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red.shade600),
                    onPressed: () => _deleteTask(task['id'].toString()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentCard(String departmentName) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.blue.shade200 : Colors.blue.shade900;

    return GestureDetector(
      onTap: () => _onDepartmentTapped(departmentName),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: _buildGlassCard(
          child: ListTile(
            title: Text(
              departmentName,
              style: GoogleFonts.almarai(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            trailing: Icon(Icons.arrow_forward_ios, color: textColor),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<dynamic> data, bool isDepartmentView) {
    if (!kIsWeb && Platform.isIOS) {
      return CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: <Widget>[
          CupertinoSliverRefreshControl(
            onRefresh: _refreshData,
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0, bottom: 16.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return isDepartmentView
                      ? _buildDepartmentCard(data[index]['department'])
                      : _buildTaskCard(data[index]);
                },
                childCount: data.length,
              ),
            ),
          ),
        ],
      );
    } else {
      return RefreshIndicator(
        onRefresh: _refreshData,
        color: Colors.blue.shade800,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0, bottom: 16.0),
          itemCount: data.length,
          itemBuilder: (context, index) {
            return isDepartmentView
                ? _buildDepartmentCard(data[index]['department'])
                : _buildTaskCard(data[index]);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final future = widget.user.role == 'Admin' && _selectedDepartment == null
        ? _departmentsFuture
        : _tasksFuture;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          _selectedDepartment != null ? 'مهام\n$_selectedDepartment' : 'المهام',
          style: GoogleFonts.almarai(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: _selectedDepartment != null ? 18 : 20,
          ),
          textAlign: TextAlign.center,
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
        leading: _selectedDepartment != null && widget.user.role == 'Admin'
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedDepartment = null;
                    _refreshData();
                  });
                },
              )
            : null,
        actions: [
          if (widget.user.role == 'Manager' || widget.user.role == 'Admin')
            IconButton(
              icon: Icon(Icons.delete_forever, color: Colors.red.shade600),
              tooltip: 'حذف جميع مهام القسم',
              onPressed: _deleteAllDepartmentTasks,
            ),
          if (widget.user.role == 'Manager' || widget.user.role == 'Admin')
            IconButton(
              icon: Icon(Icons.add_task, color: Colors.blue.shade600),
              tooltip: 'إضافة مهمة جديدة',
              onPressed: () async {
                HapticFeedback.lightImpact();
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddTaskPage(user: widget.user),
                  ),
                );
                if (result == true) {
                  _refreshData();
                }
              },
            ),
        ],
      ),
      extendBodyBehindAppBar: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: FutureBuilder<List<dynamic>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                child: !kIsWeb && Platform.isIOS ? const CupertinoActivityIndicator(radius: 15) : const CircularProgressIndicator(),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'فشل جلب البيانات: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.almarai(color: Theme.of(context).colorScheme.error),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    widget.user.role == 'Admin' && _selectedDepartment == null
                        ? 'لا توجد أقسام متاحة.'
                        : (_selectedDepartment != null
                            ? 'لا توجد مهام حالياً في قسم $_selectedDepartment.'
                            : 'لا توجد مهام حالياً.'),
                    style: GoogleFonts.almarai(),
                    textAlign: TextAlign.center,
                  ),
                );
              } else {
                final data = snapshot.data!;
                final isDepartmentView = widget.user.role == 'Admin' && _selectedDepartment == null;
                return _buildContent(data, isDepartmentView);
              }
            },
          ),
        ),
      ),
    );
  }
}