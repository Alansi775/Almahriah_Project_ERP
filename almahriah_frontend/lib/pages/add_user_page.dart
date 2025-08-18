import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:almahriah_frontend/models/user.dart'; // Import the User model

class AddUserPage extends StatefulWidget {
  final User user; // Add this line to receive the user object
  const AddUserPage({super.key, required this.user});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedDepartment;
  String? _selectedRole;
  String _message = '';

  final List<String> departments = [
    'برامج',
    'أخبار',
    'سوشال ميديا',
    'موارد بشرية',
    'استقبال',
  ];

  final List<String> roles = [
    'Admin',
    'Manager', // Changed "Management" to "Manager" to match the backend
    'News',
    'HR',
    'Employee',
  ];

  void _addUser() async {
    setState(() {
      _message = '';
    });

    if (_fullNameController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _selectedDepartment == null ||
        _selectedRole == null) {
      setState(() {
        _message = 'الرجاء إدخال جميع الحقول';
      });
      return;
    }
    
    final username = _usernameController.text.contains('@')
        ? _usernameController.text
        : '${_usernameController.text}@almahriah.com';

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.107:5050/api/admin/users'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}', // ADDED TOKEN HERE
        },
        body: json.encode({
          'username': username,
          'password': _passwordController.text,
          'fullName': _fullNameController.text,
          'department': _selectedDepartment,
          'role': _selectedRole,
        }),
      );

      final responseBody = json.decode(response.body);
      if (response.statusCode == 201) {
        setState(() {
          _message = 'تم إضافة المستخدم بنجاح!';
          _fullNameController.clear();
          _usernameController.clear();
          _passwordController.clear();
          _selectedDepartment = null;
          _selectedRole = null;
          _formKey.currentState?.reset();
        });
      } else {
        setState(() {
          _message = responseBody['message'] ?? 'فشل إضافة المستخدم';
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        _message = 'حدث خطأ في الاتصال بالخادم';
      });
    }
  }

  Widget _buildSimpleTag({required String text, bool isSelected = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE3F2FD)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: Colors.blue.shade800, width: 1.5)
              : null,
        ),
        child: Text(
          text,
          style: GoogleFonts.almarai(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue.shade900 : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildCleanTextField({
    required TextEditingController controller,
    required String labelText,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      style: GoogleFonts.poppins(color: Colors.black87),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.poppins(color: Colors.black54),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
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
          'إضافة مستخدم جديد',
          style: GoogleFonts.almarai(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 22),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'تعبئة بيانات المستخدم',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.almarai(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'سيتم استخدام هذه البيانات لإضافة حساب جديد.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.almarai(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildCleanTextField(
                    controller: _fullNameController,
                    labelText: 'الاسم الكامل',
                  ),
                  const SizedBox(height: 15),
                  _buildCleanTextField(
                    controller: _usernameController,
                    labelText: 'اسم المستخدم (بدون @almahriah.com)',
                  ),
                  const SizedBox(height: 15),
                  _buildCleanTextField(
                    controller: _passwordController,
                    labelText: 'كلمة المرور',
                    isPassword: true,
                  ),
                  const SizedBox(height: 25),

                  Text(
                    'القسم',
                    style: GoogleFonts.almarai(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: departments.map((department) {
                      return _buildSimpleTag(
                        text: department,
                        isSelected: _selectedDepartment == department,
                        onTap: () {
                          setState(() {
                            _selectedDepartment = department;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 25),

                  Text(
                    'الدور',
                    style: GoogleFonts.almarai(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: roles.map((role) {
                      return _buildSimpleTag(
                        text: role,
                        isSelected: _selectedRole == role,
                        onTap: () {
                          setState(() {
                            _selectedRole = role;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),

                  if (_message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _buildGlassMessage(
                        message: _message,
                        isSuccess: _message.contains('بنجاح'),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _addUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                      shadowColor: Colors.black.withOpacity(0.2),
                    ),
                    child: Text(
                      'إضافة المستخدم',
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
}