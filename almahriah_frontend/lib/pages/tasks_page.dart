import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:almahriah_frontend/pages/add_task_page.dart';
import 'package:almahriah_frontend/pages/task_details_page.dart';

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
    if (widget.user.role == 'Admin') {
      _departmentsFuture = _fetchDepartments();
    } else {
      _tasksFuture = _fetchTasks();
    }
  }

  Future<List<dynamic>> _fetchDepartments() async {
    final response = await http.get(
      Uri.parse('http://192.168.1.107:5050/api/admin/departments'),
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
      apiUrl = 'http://192.168.1.107:5050/api/tasks/by-department?department=$department';
    } else if (widget.user.role == 'Manager') {
      apiUrl = 'http://192.168.1.107:5050/api/tasks/by-department';
    } else {
      apiUrl = 'http://192.168.1.107:5050/api/tasks/by-user';
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

  Future<void> _deleteAllDepartmentTasks() async {
    // Show a confirmation dialog before deleting
    final confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('تأكيد الحذف', style: GoogleFonts.almarai()),
          content: Text(
            'هل أنت متأكد أنك تريد حذف جميع مهام قسمك؟ لا يمكن التراجع عن هذا الإجراء.',
            style: GoogleFonts.almarai(),
          ),
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

    if (confirm != true) {
      return; // User canceled the operation
    }

    try {
      final url = Uri.parse('http://192.168.1.107:5050/api/tasks/by-department');
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.user.token}',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(json.decode(response.body)['message'], style: GoogleFonts.almarai()),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the tasks list after deletion
        setState(() {
          _tasksFuture = _fetchTasks();
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(json.decode(response.body)['message'], style: GoogleFonts.almarai()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في الاتصال بالخادم: $e', style: GoogleFonts.almarai()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteTask(String taskId) async {
    final confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('تأكيد الحذف', style: GoogleFonts.almarai()),
          content: Text('هل أنت متأكد أنك تريد حذف هذه المهمة؟', style: GoogleFonts.almarai()),
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

    if (confirm != true) {
      return;
    }

    try {
      final url = Uri.parse('http://192.168.1.107:5050/api/tasks/$taskId');
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.user.token}',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف المهمة بنجاح!', style: GoogleFonts.almarai()),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the tasks list
        setState(() {
          _tasksFuture = _fetchTasks(department: _selectedDepartment);
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حذف المهمة: ${json.decode(response.body)['message']}', style: GoogleFonts.almarai()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في الاتصال بالخادم: $e', style: GoogleFonts.almarai()),
          backgroundColor: Colors.red,
        ),
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
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
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
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailsPage(task: task),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: _buildGlassCard(
          child: ListTile(
            title: Text(
              task['title'] ?? 'لا يوجد عنوان',
              style: GoogleFonts.almarai(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 5),
                Text(
                  'المسؤول: ${task['assignedToName'] ?? 'غير محدد'}',
                  style: GoogleFonts.almarai(fontSize: 14, color: Colors.black54),
                ),
                Text(
                  'الأولوية: ${task['priority'] ?? 'غير محدد'}',
                  style: GoogleFonts.almarai(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(task['status'] ?? 'غير محدد').withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _mapStatusToArabic(task['status'] ?? 'غير محدد'),
                    style: GoogleFonts.almarai(
                      fontSize: 14,
                      color: _getStatusColor(task['status'] ?? 'غير محدد'),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.user.role == 'Manager') ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red.shade600),
                    onPressed: () => _deleteTask(task['id'].toString()),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentCard(String departmentName) {
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
                color: Colors.blue.shade900,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.blue),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminView() {
    if (_selectedDepartment == null) {
      return FutureBuilder<List<dynamic>>(
        future: _departmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'فشل جلب الأقسام: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: GoogleFonts.almarai(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'لا توجد أقسام متاحة.',
                style: GoogleFonts.almarai(),
              ),
            );
          } else {
            final departments = snapshot.data!;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: departments.length,
                  itemBuilder: (context, index) {
                    return _buildDepartmentCard(departments[index]['department']);
                  },
                ),
              ),
            );
          }
        },
      );
    } else {
      return FutureBuilder<List<dynamic>>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'فشل جلب المهام: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: GoogleFonts.almarai(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'لا توجد مهام حالياً في قسم $_selectedDepartment.',
                style: GoogleFonts.almarai(),
              ),
            );
          } else {
            final tasks = snapshot.data!;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _buildTaskCard(task);
                  },
                ),
              ),
            );
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          _selectedDepartment != null ? 'مهام قسم $_selectedDepartment' : 'إدارة المهام والمشاريع',
          style: GoogleFonts.almarai(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        leading: _selectedDepartment != null && widget.user.role == 'Admin'
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedDepartment = null;
                  });
                },
              )
            : null,
        actions: [
          if (widget.user.role == 'Manager')
            IconButton(
              icon: Icon(Icons.delete_forever, color: Colors.red.shade600),
              tooltip: 'حذف جميع المهام',
              onPressed: _deleteAllDepartmentTasks,
            ),
          if (widget.user.role == 'Manager')
            IconButton(
              icon: Icon(Icons.add_task, color: Colors.blue.shade600),
              tooltip: 'إضافة مهمة جديدة',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddTaskPage(user: widget.user),
                  ),
                );
                if (result == true) {
                  setState(() {
                    _tasksFuture = _fetchTasks();
                  });
                }
              },
            ),
        ],
      ),
      body: widget.user.role == 'Admin'
          ? _buildAdminView()
          : FutureBuilder<List<dynamic>>(
              future: _tasksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'فشل جلب المهام: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.almarai(color: Colors.red),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'لا توجد مهام حالياً.',
                      style: GoogleFonts.almarai(),
                    ),
                  );
                } else {
                  final tasks = snapshot.data!;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _buildTaskCard(task);
                        },
                      ),
                    ),
                  );
                }
              },
            ),
    );
  }
}