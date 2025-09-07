// lib/pages/hr_dashboard.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/pages/leave_requests_page.dart';
import 'package:almahriah_frontend/pages/leave_history_page.dart';
import 'package:almahriah_frontend/pages/employee_list_page.dart';
import 'package:almahriah_frontend/pages/tasks_page.dart';
import 'package:almahriah_frontend/services/auth_service.dart';
import 'package:almahriah_frontend/widgets/glassmorphism_widgets.dart';
import 'package:almahriah_frontend/widgets/action_widgets.dart';
import 'package:almahriah_frontend/pages/ai.dart';
import 'package:almahriah_frontend/widgets/animated_ai_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:almahriah_frontend/pages/chat_list_page.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// ✅ إضافة الاستيرادات الجديدة
import 'package:almahriah_frontend/pages/image_picker_page.dart';
import 'package:almahriah_frontend/services/profile_utils.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const platform = MethodChannel('com.almahriah.app/dialog');

  // ✅ إضافة متغير حالة الصورة
  String? _currentProfilePictureUrl;

  @override
  void initState() {
    super.initState();
    _currentProfilePictureUrl = widget.user.profilePictureUrl;
    _updateUserProfilePicture(); // ✅ استدعاء الدالة عند التهيئة
  }
  
  // ✅ إضافة دالة جلب وتحديث الصورة
  Future<void> _updateUserProfilePicture() async {
    try {
      final userResponse = await http.get(
        // ✅ استخدام المسار الذي يعمل مع صلاحيات المدير والـ HR
        Uri.parse('http://192.168.1.65:5050/api/admin/users/${widget.user.id}'),
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
              ? 'http://192.168.1.65:5050${userData['profilePictureUrl']}'
              : null;
          });
        }
      }
    } catch (e) {
      print('خطأ في تحديث صورة HR: $e');
    }
  }


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
        title: Image.asset('assets/logo.png', height: 35),
        centerTitle: true,
        actions: [
          // ✅ إضافة زر التحديث
          if (kIsWeb || !kIsWeb && Platform.isAndroid)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: _updateUserProfilePicture,
            ),
          if (!kIsWeb && Platform.isIOS)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _updateUserProfilePicture,
              child: const Icon(Icons.refresh, color: Colors.black),
            ),
          const SizedBox(width: 10),
        ],
      ),
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
                      // ✅ استبدال CircleAvatar الحالي بالكود الجديد
                      GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImagePickerPage(user: widget.user),
                            ),
                          );
                          
                          if (result == true && mounted) {
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
                                        style: GoogleFonts.poppins(
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
              ListTile(
                leading: const Icon(CupertinoIcons.chat_bubble_2, color: Colors.blueAccent),
                title: Text('المحادثات', style: GoogleFonts.almarai()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChatListPage(user: widget.user)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.pending_actions, color: Colors.orange),
                title: Text('طلبات الإجازة المعلقة', style: GoogleFonts.almarai()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LeaveRequestsPage(user: widget.user),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.blue),
                title: Text('سجل الإجازات', style: GoogleFonts.almarai()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LeaveHistoryPage(user: widget.user),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1, color: Colors.teal),
                title: Text('قائمة الموظفين', style: GoogleFonts.almarai()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmployeeListPage(user: widget.user),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.task_alt, color: Colors.purple),
                title: Text('المهام والمشاريع', style: GoogleFonts.almarai()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TasksPage(user: widget.user),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner, color: Colors.green),
                title: Text('إنشاء رمز QR للدخول', style: GoogleFonts.almarai()),
                onTap: () {
                  Navigator.pop(context);
                  AuthService.generateQrCode(context, widget.user);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                title: Text('تسجيل الخروج', style: GoogleFonts.almarai()),
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
                buildGlassTag(text: 'دورك: ${widget.user.role} - ${widget.user.department}'),
                const SizedBox(height: 30),
                buildGlassCard(
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
                          buildGlassButton(
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
                          buildGlassButton(
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
                          buildGlassButton(
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
                          buildGlassButton(
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
                          buildGlassButton(
                            context: context,
                            label: 'إنشاء رمز QR للدخول',
                            icon: Icons.qr_code_scanner,
                            onPressed: () => AuthService.generateQrCode(context, widget.user),
                            color: Colors.green.shade800,
                          ),
                          buildGlassButton(
                            context: context,
                            label: 'تسجيل الخروج',
                            icon: Icons.exit_to_app,
                            onPressed: () => _showAlert(
                              'تسجيل الخروج',
                              'هل أنت متأكد من أنك تريد تسجيل الخروج؟'
                            ),
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