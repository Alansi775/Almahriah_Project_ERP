// almahriah_frontend/lib/pages/leave_requests_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:almahriah_frontend/models/user.dart';

class LeaveRequestsPage extends StatefulWidget {
  final User user;
  
  const LeaveRequestsPage({super.key, required this.user});

  @override
  State<LeaveRequestsPage> createState() => _LeaveRequestsPageState();
}

class _LeaveRequestsPageState extends State<LeaveRequestsPage> {
  late Future<List<dynamic>> _pendingRequestsFuture;

  @override
  void initState() {
    super.initState();
    _pendingRequestsFuture = _fetchPendingLeaveRequests();
  }

  // دالة لجلب طلبات الإجازة المعلقة
  Future<List<dynamic>> _fetchPendingLeaveRequests() async {
    final url = Uri.parse('http://192.168.1.107:5050/api/admin/leave-requests/pending');
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
      throw Exception('فشل جلب طلبات الإجازة المعلقة: ${response.body}');
    }
  }

  // دالة لتحديث حالة الطلب
  Future<void> _updateLeaveRequestStatus(int requestId, String status) async {
    final url = Uri.parse('http://192.168.1.107:5050/api/admin/leave-requests/update-status/$requestId');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.user.token}',
      },
      body: jsonEncode({'status': status}),
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث حالة الطلب بنجاح.', style: GoogleFonts.almarai())),
      );
      setState(() {
        _pendingRequestsFuture = _fetchPendingLeaveRequests();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحديث حالة الطلب: ${json.decode(response.body)['message']}', style: GoogleFonts.almarai())),
      );
    }
  }
  
  // دالة لحساب عدد الأيام بين تاريخين
  int _calculateDays(String startDate, String endDate) {
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    return end.difference(start).inDays + 1;
  }

  // دالة التصميم الزجاجي (Glassmorphism) مع إضافة الظلال
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
  
  // دالة بناء وسم أنيق (Tag)
  Widget _buildStylishTag(String text, {Color? color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? Colors.blue.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade800),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.almarai(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
          ),
        ],
      ),
    );
  }

  // بناء بطاقة طلب الإجازة
  Widget _buildRequestCard(Map<String, dynamic> request) {
    final startDate = DateFormat('yyyy-MM-dd').format(DateTime.parse(request['startDate']));
    final endDate = DateFormat('yyyy-MM-dd').format(DateTime.parse(request['endDate']));
    final days = _calculateDays(request['startDate'], request['endDate']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: _buildGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // معلومات الموظف
            Row(
              children: [
                const Icon(Icons.person, color: Colors.black87, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${request['fullName']} - ${request['department']}',
                    style: GoogleFonts.almarai(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 25, color: Colors.black26),
            
            // تفاصيل الإجازة
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildStylishTag('$days يوم', icon: Icons.calendar_today),
                _buildStylishTag('من $startDate', icon: Icons.date_range),
                _buildStylishTag('إلى $endDate', icon: Icons.date_range),
              ],
            ),
            
            const SizedBox(height: 15),

            // السبب
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.black54, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'السبب: ${request['reason']}',
                    style: GoogleFonts.almarai(fontSize: 16, fontStyle: FontStyle.italic),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // أزرار الإجراءات
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _updateLeaveRequestStatus(request['id'], 'Accepted'),
                  icon: const Icon(Icons.check, size: 20),
                  label: Text('قبول', style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _updateLeaveRequestStatus(request['id'], 'Rejected'),
                  icon: const Icon(Icons.close, size: 20),
                  label: Text('رفض', style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
        foregroundColor: Colors.black,
        title: Text(
          'طلبات الإجازة المعلقة',
          style: GoogleFonts.almarai(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: () {
              setState(() {
                _pendingRequestsFuture = _fetchPendingLeaveRequests();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _pendingRequestsFuture,
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
                'لا توجد طلبات إجازة معلقة حالياً.',
                style: GoogleFonts.almarai(),
              ),
            );
          } else {
            final requests = snapshot.data!;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return _buildRequestCard(request);
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