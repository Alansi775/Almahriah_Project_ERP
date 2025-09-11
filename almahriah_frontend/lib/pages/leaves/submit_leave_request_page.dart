// almahriah_frontend/lib/pages/submit_leave_request_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:almahriah_frontend/models/user.dart';
import 'package:flutter/services.dart';

class SubmitLeaveRequestPage extends StatefulWidget {
  final User user;
  
  const SubmitLeaveRequestPage({super.key, required this.user});

  @override
  State<SubmitLeaveRequestPage> createState() => _SubmitLeaveRequestPageState();
}

class _SubmitLeaveRequestPageState extends State<SubmitLeaveRequestPage> {
  final _reasonController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _message = '';
  bool _isLoading = false;

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
      locale: const Locale('en', 'US'),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue.shade800,
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade800,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
            textTheme: TextTheme(
              bodyLarge: GoogleFonts.almarai(),
              bodyMedium: GoogleFonts.almarai(),
              headlineSmall: GoogleFonts.almarai(fontWeight: FontWeight.bold),
              titleLarge: GoogleFonts.almarai(),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _submitRequest() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });

    if (_startDate == null || _endDate == null || _reasonController.text.isEmpty) {
      setState(() {
        _message = 'الرجاء إدخال جميع الحقول.';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.78:5050/api/admin/leave-requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}',
        },
        body: json.encode({
          'userId': widget.user.id,
          'startDate': _startDate!.toIso8601String().split('T')[0],
          'endDate': _endDate!.toIso8601String().split('T')[0],
          'reason': _reasonController.text,
        }),
      );
      
      final responseBody = json.decode(response.body);
      if (response.statusCode == 201) {
        setState(() {
          _message = 'تم إرسال الطلب بنجاح!';
          _reasonController.clear();
          _startDate = null;
          _endDate = null;
        });
      } else {
        setState(() {
          _message = responseBody['message'] ?? 'فشل إرسال الطلب.';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'حدث خطأ في الاتصال بالخادم.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // دالة لتصميم البطاقات الزجاجية
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

  @override
  Widget build(BuildContext context) {
    // **التعديل هنا: تغليف Scaffold بـ Theme لتغيير لون التظليل**
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.blue.shade800, // لون المؤشر
          selectionColor: Colors.blue.shade200, // لون التظليل
          selectionHandleColor: Colors.blue.shade800, // لون مقابض التحديد
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'تقديم طلب إجازة',
            style: GoogleFonts.almarai(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 22),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'املأ النموذج لتقديم طلب إجازة',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.almarai(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildGlassCard(
                    child: Column(
                      children: [
                        _buildDateTile(
                          text: _startDate == null ? 'تاريخ البداية' : 'تاريخ البداية: ${_startDate!.toLocal().toString().split(' ')[0]}',
                          onTap: () => _selectDate(context, true),
                        ),
                        const SizedBox(height: 15),
                        _buildDateTile(
                          text: _endDate == null ? 'تاريخ النهاية' : 'تاريخ النهاية: ${_endDate!.toLocal().toString().split(' ')[0]}',
                          onTap: () => _selectDate(context, false),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: _reasonController,
                          maxLines: 5,
                          style: GoogleFonts.almarai(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'سبب الإجازة',
                            labelStyle: GoogleFonts.almarai(color: Colors.black54),
                            filled: true,
                            fillColor: const Color(0xFFF0F4F8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.blue.shade100,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.blue.shade100,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.blue.shade800,
                                width: 2.0,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  if (_message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.almarai(
                          color: _message.contains('بنجاح') ? Colors.green.shade700 : Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'إرسال الطلب',
                            style: GoogleFonts.almarai(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTile({required String text, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.0),
      ),
      child: ListTile(
        title: Text(
          text,
          style: GoogleFonts.almarai(color: Colors.black87, fontSize: 16),
        ),
        trailing: const Icon(Icons.calendar_today, color: Colors.blue),
        onTap: onTap,
      ),
    );
  }
}