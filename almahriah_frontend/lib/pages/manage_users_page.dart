import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:almahriah_frontend/models/user.dart'; // لا تنسَ إضافة هذا الاستيراد

class ManageUsersPage extends StatefulWidget {
  final User user; // إضافة كائن المستخدم هنا
  const ManageUsersPage({super.key, required this.user});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  List<dynamic> users = [];
  bool isLoading = true;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.107:5050/api/admin/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}', // إضافة التوكن هنا
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          users = json.decode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          _message = 'فشل جلب المستخدمين: ${json.decode(response.body)['message']}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = 'حدث خطأ في الاتصال بالخادم';
        isLoading = false;
      });
    }
  }

  Future<void> _toggleUserActiveStatus(int userId, bool isActive) async {
    if (userId == 1) {
      setState(() {
        _message = 'لا يمكن تعطيل حساب المسؤول الرئيسي.';
      });
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('http://192.168.1.107:5050/api/admin/users/$userId/toggle-active'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}', // إضافة التوكن هنا
        },
        body: json.encode({'isActive': !isActive}),
      );
      if (response.statusCode == 200) {
        setState(() {
          _fetchUsers();
          _message = json.decode(response.body)['message'];
        });
      } else {
        setState(() {
          _message = json.decode(response.body)['message'] ?? 'فشل تحديث حالة المستخدم';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'حدث خطأ في الاتصال بالخادم';
      });
    }
  }

  Future<void> _deleteUser(int userId) async {
    if (userId == 1) {
      setState(() {
        _message = 'لا يمكن حذف حساب المسؤول الرئيسي.';
      });
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('http://192.168.1.107:5050/api/admin/users/$userId'),
        headers: {
          'Authorization': 'Bearer ${widget.user.token}', // إضافة التوكن هنا
        },
      );

      final responseBody = json.decode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _fetchUsers();
          _message = responseBody['message'] ?? 'تم حذف المستخدم بنجاح.';
        });
      } else {
        setState(() {
          _message = responseBody['message'] ?? 'فشل حذف المستخدم.';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'حدث خطأ في الاتصال بالخادم.';
      });
    }
  }

  Widget _buildGlassMessage({required String message, required bool isSuccess}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isSuccess
                ? Colors.green.shade50.withOpacity(0.5)
                : Colors.red.shade50.withOpacity(0.5),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSuccess
                  ? Colors.green.shade400.withOpacity(0.4)
                  : Colors.red.shade400.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.almarai(
              color: isSuccess ? Colors.green.shade900 : Colors.red.shade900,
              fontWeight: FontWeight.bold,
            ),
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
        title: Text(
          'التحكم في المستخدمين',
          style: GoogleFonts.almarai(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 22),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_message.isNotEmpty && users.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _buildGlassMessage(message: _message, isSuccess: false),
              ),
            )
          else if (users.isEmpty)
            Center(
              child: Text(
                'لا يوجد مستخدمون حالياً.',
                style: GoogleFonts.almarai(fontSize: 20, color: Colors.black54),
              ),
            )
          else
            ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final String initials = user['fullName'] != null && user['fullName'].isNotEmpty
                    ? (user['fullName'] as String).split(' ').map((s) => s.isNotEmpty ? s[0] : '').join().substring(0, user['fullName'].split(' ').map((s) => s.isNotEmpty ? s[0] : '').join().length > 1 ? 2 : 1).toUpperCase()
                    : (user['username'] as String).substring(0, 2).toUpperCase();
                
                final bool isMainAdmin = user['id'] == 1;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          leading: CircleAvatar(
                            backgroundColor: user['isActive'] == 1 ? Colors.green.shade400 : Colors.red.shade400,
                            radius: 25,
                            child: Text(
                              initials,
                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          title: Text(
                            user['fullName'] ?? user['username'],
                            style: GoogleFonts.almarai(fontWeight: FontWeight.w600, color: Colors.black87),
                          ),
                          subtitle: Text(
                            '${user['department']} - ${user['role']}',
                            style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Delete Button
                              if (!isMainAdmin)
                                IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                                  onPressed: () {
                                    _deleteUser(user['id']);
                                  },
                                ),
                              // Toggle Active Status Switch
                              if (!isMainAdmin)
                                Switch(
                                  value: user['isActive'] == 1,
                                  onChanged: (bool value) {
                                    _toggleUserActiveStatus(user['id'], user['isActive'] == 1);
                                  },
                                  activeColor: Colors.green,
                                  inactiveTrackColor: Colors.red.shade100,
                                  inactiveThumbColor: Colors.red,
                                )
                              else
                                const Icon(Icons.lock_outline, color: Colors.black45),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          if (_message.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: _buildGlassMessage(
                message: _message,
                isSuccess: _message.contains('بنجاح'),
              ),
            ),
        ],
      ),
    );
  }
}