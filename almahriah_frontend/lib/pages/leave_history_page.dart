// almahriah_frontend/lib/pages/leave_history_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:almahriah_frontend/widgets/glassmorphism_widgets.dart';

class LeaveHistoryPage extends StatefulWidget {
  final User user;
  const LeaveHistoryPage({super.key, required this.user});

  @override
  State<LeaveHistoryPage> createState() => _LeaveHistoryPageState();
}

class _LeaveHistoryPageState extends State<LeaveHistoryPage> {
  late Future<List<dynamic>> _leaveRequestsFuture;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _leaveRequestsFuture = _fetchLeaveHistory();
  }

  // دالة لجلب جميع طلبات الإجازة من الخادم
  Future<List<dynamic>> _fetchLeaveHistory() async {
    final url = Uri.parse('http://192.168.1.67:5050/api/admin/leave-requests/all');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.user.token}',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('فشل جلب سجل الإجازات: ${response.body}');
    }
  }

  // دالة لحذف جميع الطلبات
  Future<void> _deleteAllLeaveRequests() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('تأكيد الحذف', style: GoogleFonts.almarai()),
          content: Text('هل أنت متأكد أنك تريد حذف جميع طلبات الإجازة؟ لا يمكن التراجع عن هذا الإجراء.', style: GoogleFonts.almarai()),
          actions: <Widget>[
            TextButton(
              child: Text('إلغاء', style: GoogleFonts.almarai()),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('حذف', style: GoogleFonts.almarai(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _isDeleting = true;
      });

      try {
        final url = Uri.parse('http://192.168.1.67:5050/api/admin/leave-requests/all');
        final response = await http.delete(
          url,
          headers: {
            'Authorization': 'Bearer ${widget.user.token}',
          },
        );

        if (!context.mounted) return;

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم حذف جميع الطلبات بنجاح!', style: GoogleFonts.almarai())),
          );
          // إعادة جلب البيانات لتحديث القائمة بعد الحذف
          setState(() {
            _leaveRequestsFuture = _fetchLeaveHistory();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل الحذف: ${json.decode(response.body)['message']}', style: GoogleFonts.almarai())),
          );
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ غير متوقع: $e', style: GoogleFonts.almarai())),
        );
      } finally {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }
  
  // دالة لحساب عدد الأيام بين تاريخين
  int _calculateDays(String startDate, String endDate) {
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    return end.difference(start).inDays + 1;
  }
  
  // بناء بطاقة الإجازة باستخدام buildGlassCard من الملف المشترك
  Widget _buildLeaveCard(Map<String, dynamic> request) {
    final status = request['status'];
    Color statusColor;
    if (status == 'Accepted') {
      statusColor = Colors.green;
    } else if (status == 'Rejected') {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.orange;
    }

    final startDate = DateFormat('yyyy-MM-dd').format(DateTime.parse(request['startDate']));
    final endDate = DateFormat('yyyy-MM-dd').format(DateTime.parse(request['endDate']));
    final days = _calculateDays(request['startDate'], request['endDate']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: buildGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${request['fullName']}',
                    style: GoogleFonts.almarai(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Chip(
                    label: Text(
                      status,
                      style: GoogleFonts.almarai(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'السبب: ${request['reason']}',
                style: GoogleFonts.almarai(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'من: $startDate',
                    style: GoogleFonts.almarai(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'إلى: $endDate',
                    style: GoogleFonts.almarai(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'عدد الأيام: $days',
                style: GoogleFonts.almarai(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
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
        title: Text(
          'سجل الإجازات',
          style: GoogleFonts.almarai(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _isDeleting ? null : _deleteAllLeaveRequests,
            tooltip: 'حذف جميع طلبات الإجازة',
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _leaveRequestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                '${snapshot.error}',
                textAlign: TextAlign.center,
                style: GoogleFonts.almarai(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'لا يوجد سجل إجازات.',
                style: GoogleFonts.almarai(),
              ),
            );
          } else {
            final requests = snapshot.data!;
            return ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return _buildLeaveCard(request);
              },
            );
          }
        },
      ),
    );
  }
}