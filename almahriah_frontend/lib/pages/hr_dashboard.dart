// almahriah_frontend/lib/pages/hr_dashboard.dart

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
import 'package:flutter/cupertino.dart'; // ✅ NEW: Import Cupertino for chat icon
import 'package:almahriah_frontend/pages/chat_list_page.dart'; // ✅ NEW: Import ChatListPage

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
      ),
      // ✅ ADDED: Drawer for navigation
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
              // ✅ NEW: Chat Tile in the Drawer
              ListTile(
                leading: const Icon(CupertinoIcons.chat_bubble_2, color: Colors.blueAccent),
                title: Text('المحادثات', style: GoogleFonts.almarai()),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChatListPage(user: widget.user)));
                },
              ),
              // The rest of the list items can be added here as needed
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
                            onPressed: () => AuthService.logout(context, widget.user.id),
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