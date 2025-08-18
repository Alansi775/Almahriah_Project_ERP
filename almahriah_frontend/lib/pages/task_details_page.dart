import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class TaskDetailsPage extends StatelessWidget {
  final Map<String, dynamic> task;

  const TaskDetailsPage({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          'تفاصيل المهمة',
          style: GoogleFonts.almarai(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.white.withOpacity(0.3)),
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 100, left: 24, right: 24, bottom: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.assignment, size: 28, color: Colors.blue.shade900),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              task['title'] ?? 'عنوان المهمة غير متوفر',
                              style: GoogleFonts.almarai(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        task['description'] ?? 'لا يوجد وصف.',
                        style: GoogleFonts.almarai(
                          fontSize: 16,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 3,
                  children: [
                    _buildIconCard(
                      icon: Icons.person,
                      title: 'المسؤول عن المهمة',
                      content: task['assignedToName'] ?? 'غير محدد',
                    ),
                    _buildIconCard(
                      icon: Icons.priority_high,
                      title: 'الأولوية',
                      content: task['priority'] ?? 'غير محدد',
                      color: _getPriorityColor(task['priority'] ?? ''),
                    ),
                    _buildIconCard(
                      icon: Icons.info,
                      title: 'الحالة',
                      content: _mapStatusToArabic(task['status'] ?? 'غير محدد'),
                      color: _getStatusColor(task['status'] ?? ''),
                    ),
                    _buildIconCard(
                      icon: Icons.calendar_today,
                      title: 'تم الإسناد بواسطة',
                      content: task['assignedByName'] ?? 'غير محدد',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildIconCard({
    required IconData icon,
    required String title,
    required String content,
    Color? color,
  }) {
    return _buildGlassCard(
      child: Row(
        children: [
          Icon(icon, size: 28, color: color ?? Colors.blue.shade900),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.almarai(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  content,
                  style: GoogleFonts.almarai(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _mapStatusToArabic(String status) {
    switch (status) {
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'completed':
        return 'مكتمل';
      case 'pending':
        return 'لم تبدأ بعد';
      default:
        return 'غير محدد';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'in_progress':
        return Colors.orange.shade800;
      case 'completed':
        return Colors.green.shade800;
      case 'pending':
        return Colors.blue.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'عاجل':
        return Colors.red.shade800;
      case 'مهم':
        return Colors.orange.shade800;
      case 'عادي':
        return Colors.blue.shade800;
      default:
        return Colors.grey.shade800;
    }
  }
}