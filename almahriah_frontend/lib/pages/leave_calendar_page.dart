// almahriah_frontend/lib/pages/leave_calendar_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:almahriah_frontend/models/user.dart';
import 'package:intl/intl.dart' as intl;

// تعريف كلاس لحالة الإجازة
class LeaveEvent {
  final String status;
  final String reason;
  final String id; // إضافة مُعرف الطلب

  LeaveEvent(this.status, this.reason, this.id);
}

class LeaveCalendarPage extends StatefulWidget {
  final User user;
  const LeaveCalendarPage({Key? key, required this.user}) : super(key: key);

  @override
  State<LeaveCalendarPage> createState() => _LeaveCalendarPageState();
}

class _LeaveCalendarPageState extends State<LeaveCalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<LeaveEvent>> _leaveDays = {};
  bool _isLoading = true;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchEmployeeLeaveRequests();
  }

  // دالة التصميم الزجاجي
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

  Future<void> _fetchEmployeeLeaveRequests() async {
    print('Fetching employee leave requests...');
    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final url = Uri.parse(
          'http://192.168.1.107:5050/api/admin/leave-requests/employee/${widget.user.id}');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.user.token}',
        },
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List requests = json.decode(response.body);
        final Map<DateTime, List<LeaveEvent>> leaveDays = {};

        for (var request in requests) {
          DateTime startDate = DateTime.parse(request['startDate']);
          DateTime endDate = DateTime.parse(request['endDate']);
          String status = request['status'];
          String reason = request['reason'];
          String id = request['id'].toString(); // التأكد من وجود id في الـ response

          print('Status from server: $status');
          
          for (DateTime d = startDate;
              d.isBefore(endDate.add(const Duration(days: 1)));
              d = d.add(const Duration(days: 1))) {
            final normalizedDate = DateTime(d.year, d.month, d.day);
            if (leaveDays[normalizedDate] == null) {
              leaveDays[normalizedDate] = [LeaveEvent(status, reason, id)];
            } else {
              leaveDays[normalizedDate]!.add(LeaveEvent(status, reason, id));
            }
          }
        }

        setState(() {
          _leaveDays = leaveDays;
          _isLoading = false;
        });
      } else {
        setState(() {
          _message =
              'فشل جلب الطلبات: ${json.decode(response.body)['message']}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = 'حدث خطأ في الاتصال بالخادم: $e';
        _isLoading = false;
      });
    }
  }

  List<LeaveEvent> _getEventsForDay(DateTime day) {
    final normalizedDate = DateTime(day.year, day.month, day.day);
    return _leaveDays[normalizedDate] ?? [];
  }

  // دالة لتحديد لون الخلفية بناءً على حالة الطلب
  Color _getEventColor(List<LeaveEvent> events) {
    if (events.isEmpty) {
      return Colors.transparent;
    }
    // أولوية الألوان: مرفوض < قيد المراجعة < معتمد
    if (events.any((event) => event.status == 'Accepted')) {
      return Colors.red.shade400.withOpacity(0.8); // أحمر
    }
    if (events.any((event) => event.status == 'Pending')) {
      return Colors.orange.shade400.withOpacity(0.8); // أصفر
    }
    if (events.any((event) => event.status == 'Rejected')) {
      return Colors.grey.shade400.withOpacity(0.8); // رمادي
    }
    return Colors.transparent;
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'Accepted':
        return 'مقبول';
      case 'Pending':
        return 'قيد المراجعة';
      case 'Rejected':
        return 'مرفوض';
      default:
        return status;
    }
  }
  
  // **الكود الجديد للحذف**
  Future<void> _deleteLeaveRequest(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تأكيد الحذف',
          style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'هل أنت متأكد أنك تريد حذف هذا الطلب؟',
          style: GoogleFonts.almarai(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.almarai(color: Colors.blue),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'حذف',
              style: GoogleFonts.almarai(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        print('Attempting to delete request with ID: $id');
        final url = Uri.parse('http://192.168.1.107:5050/api/admin/leave-requests/$id');
        final response = await http.delete(
          url,
          headers: {
            'Authorization': 'Bearer ${widget.user.token}',
          },
        );
        print('Delete Response Status: ${response.statusCode}');
        print('Delete Response Body: ${response.body}');

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم حذف الطلب بنجاح', style: GoogleFonts.almarai())),
          );
          _fetchEmployeeLeaveRequests(); // تحديث التقويم بعد الحذف
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل حذف الطلب', style: GoogleFonts.almarai())),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e', style: GoogleFonts.almarai())),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'تقويم الإجازات',
          style: GoogleFonts.almarai(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _fetchEmployeeLeaveRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: SizedBox(
                  width: 800,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGlassCard(
                        child: TableCalendar(
                          locale: 'ar_EG',
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          calendarFormat: _calendarFormat,
                          selectedDayPredicate: (day) {
                            return isSameDay(_selectedDay, day);
                          },
                          onDaySelected: (selectedDay, focusedDay) {
                            if (!isSameDay(_selectedDay, selectedDay)) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            }
                          },
                          onFormatChanged: (format) {
                            if (_calendarFormat != format) {
                              setState(() {
                                _calendarFormat = format;
                              });
                            }
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                          },
                          eventLoader: _getEventsForDay,
                          // تخصيص رأس التقويم
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            leftChevronMargin: EdgeInsets.symmetric(horizontal: 10),
                            rightChevronMargin: EdgeInsets.symmetric(horizontal: 10),
                          ),
                          // تخصيص مظهر الأيام
                          calendarBuilders: CalendarBuilders(
                            // تعديل الـ defaultBuilder لاستخدام الألوان الجديدة
                            defaultBuilder: (context, day, focusedDay) {
                              final events = _getEventsForDay(day);
                              if (events.isNotEmpty) {
                                final isLeaveDay = events.isNotEmpty;
                                final eventColor = _getEventColor(events);
                                if (isLeaveDay) {
                                  return Container(
                                    margin: const EdgeInsets.all(4.0),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: eventColor,
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    child: Text(
                                      '${day.day}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                }
                              }
                              // الأيام العادية (بالأرقام الإنجليزية)
                              return Center(
                                child: Text(
                                  '${day.day}',
                                  style: GoogleFonts.almarai(color: Colors.black87),
                                ),
                              );
                            },
                            // تخصيص شكل اليوم المحدد
                            selectedBuilder: (context, date, focusedDay) {
                              final events = _getEventsForDay(date);
                              final isLeaveDay = events.isNotEmpty;
                              final eventColor = isLeaveDay ? _getEventColor(events) : Colors.blue.shade800;
                              return Container(
                                margin: const EdgeInsets.all(4.0),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: eventColor,
                                  borderRadius: BorderRadius.circular(10.0),
                                  border: isLeaveDay ? null : Border.all(color: Colors.white, width: 2),
                                ),
                                child: Text(
                                  '${date.day}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            },
                            // تخصيص شكل اليوم الحالي
                            todayBuilder: (context, date, focusedDay) {
                              final events = _getEventsForDay(date);
                              final isLeaveDay = events.isNotEmpty;
                              final eventColor = isLeaveDay ? _getEventColor(events) : Colors.blue.shade200.withOpacity(0.5);
                              return Container(
                                margin: const EdgeInsets.all(4.0),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: eventColor,
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                child: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    color: isLeaveDay ? Colors.white : Colors.black87,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'تفاصيل إجازات اليوم المحدد',
                        style: GoogleFonts.almarai(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 15),
                      if (_selectedDay != null && _getEventsForDay(_selectedDay!).isNotEmpty)
                        _buildGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _getEventsForDay(_selectedDay!)
                                .map(
                                  (event) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      event.status == 'Accepted' ? Icons.check_circle : event.status == 'Pending' ? Icons.watch_later_outlined : Icons.cancel,
                                      color: event.status == 'Accepted' ? Colors.green : event.status == 'Pending' ? Colors.orange : Colors.grey,
                                      size: 30,
                                    ),
                                    title: Text(
                                      _getStatusText(event.status),
                                      style: GoogleFonts.almarai(
                                        fontWeight: FontWeight.bold,
                                        color: event.status == 'Accepted' ? Colors.green : event.status == 'Pending' ? Colors.orange : Colors.grey,
                                      ),
                                    ),
                                    subtitle: Text(
                                      event.reason,
                                      style: GoogleFonts.almarai(),
                                    ),
                                    trailing:
                                    // **إضافة زر الحذف**
                                    event.status == 'Pending'
                                        ? IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _deleteLeaveRequest(event.id),
                                          )
                                        : null,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      if (_selectedDay != null && _getEventsForDay(_selectedDay!).isEmpty)
                        Center(
                          child: Text(
                            'لا توجد إجازات في هذا اليوم.',
                            style: GoogleFonts.almarai(fontSize: 16, color: Colors.black54),
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